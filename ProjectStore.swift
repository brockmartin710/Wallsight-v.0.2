import Foundation
import SwiftUI
import PDFKit

struct ImportedDrawing: Codable, Identifiable, Equatable {
    var id: UUID
    var filename: String
    var title: String
    var sheetNumber: String
    var pageCount: Int
    var wallTags: [String]
    var sheetReferences: [String]
    var dimensionMentions: Int

    var summary: String {
        "\(pageCount) page(s) • \(wallTags.count) wall-tag types • \(dimensionMentions) dimension-like text matches"
    }
}

@MainActor
final class ProjectStore: ObservableObject {
    @Published var drawings: [ImportedDrawing] = []
    @Published var message = ""
    @Published var building: BuildingModel = .empty
    @Published var importing = false

    private let fm = FileManager.default

    private var drawingsFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("WallSightDrawings", isDirectory: true)
    }

    private var manifestURL: URL {
        drawingsFolder.appendingPathComponent("drawing_index.json")
    }

    private var editedModelURL: URL {
        drawingsFolder.appendingPathComponent("heath_model_edits.json")
    }

    init() {
        do {
            building = try BuildingModel.loadBundled()
        } catch {
            message = error.localizedDescription
        }
        try? fm.createDirectory(at: drawingsFolder, withIntermediateDirectories: true)
        if let edited = try? Data(contentsOf: editedModelURL),
           let saved = try? JSONDecoder().decode(BuildingModel.self, from: edited) {
            building = saved
        }
        if let data = try? Data(contentsOf: manifestURL),
           let list = try? JSONDecoder().decode([ImportedDrawing].self, from: data) {
            drawings = list
        }
    }

    func url(for drawing: ImportedDrawing) -> URL {
        drawingsFolder.appendingPathComponent(drawing.filename)
    }

    func importPDFs(_ urls: [URL]) {
        importing = true
        defer { importing = false }
        var succeeded = 0
        var errors: [String] = []
        for original in urls {
            let scoped = original.startAccessingSecurityScopedResource()
            defer { if scoped { original.stopAccessingSecurityScopedResource() } }
            do {
                guard original.pathExtension.lowercased() == "pdf" else {
                    throw NSError(domain: "WallSight", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not a PDF"])
                }
                let filename = UUID().uuidString + ".pdf"
                let destination = drawingsFolder.appendingPathComponent(filename)
                try fm.copyItem(at: original, to: destination)
                guard let pdf = PDFDocument(url: destination), pdf.pageCount > 0 else {
                    try? fm.removeItem(at: destination)
                    throw NSError(domain: "WallSight", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not open PDF"])
                }
                let analysis = DrawingTextAnalysis.analyze(pdf: pdf, filename: original.deletingPathExtension().lastPathComponent)
                drawings.append(ImportedDrawing(
                    id: UUID(), filename: filename,
                    title: original.deletingPathExtension().lastPathComponent,
                    sheetNumber: analysis.sheet,
                    pageCount: pdf.pageCount,
                    wallTags: analysis.wallTags,
                    sheetReferences: analysis.references,
                    dimensionMentions: analysis.dimensionCount
                ))
                succeeded += 1
            } catch {
                errors.append("\(original.lastPathComponent): \(error.localizedDescription)")
            }
        }
        persist()
        message = "Imported \(succeeded) PDF(s). Text detection is preliminary, NOT automatic 3D reconstruction." + (errors.isEmpty ? "" : " Errors: " + errors.joined(separator: "; "))
    }

    func renameSheet(_ drawing: ImportedDrawing, to sheet: String) {
        guard let index = drawings.firstIndex(where: { $0.id == drawing.id }) else { return }
        drawings[index].sheetNumber = sheet.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func importModelJSON(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let candidate = try JSONDecoder().decode(BuildingModel.self, from: Data(contentsOf: url))
            guard candidate.widthMeters > 0, candidate.depthMeters > 0,
                  !candidate.walls.isEmpty else {
                throw NSError(domain: "WallSight", code: 4, userInfo: [NSLocalizedDescriptionKey: "Model JSON has no usable footprint/walls."])
            }
            building = candidate
            persistBuilding()
            message = "Imported 3D JSON model. Verify all coordinates before relying on it."
        } catch {
            message = "Model import failed: \(error.localizedDescription)"
        }
    }

    /// Correct unverified draft geometry. These edits are saved locally on the phone.
    func updateWall(_ wallID: String, startXFeet: Double, startZFeet: Double,
                    endXFeet: Double, endZFeet: Double, heightFeet: Double) {
        guard let index = building.walls.firstIndex(where: { $0.id == wallID }) else { return }
        var walls = building.walls
        let old = walls[index]
        walls[index] = ModelWall(
            id: old.id, tag: old.tag,
            start: PlanPoint(x: startXFeet * 0.3048, z: startZFeet * 0.3048),
            end: PlanPoint(x: endXFeet * 0.3048, z: endZFeet * 0.3048),
            thicknessMeters: old.thicknessMeters, heightMeters: heightFeet * 0.3048,
            sourceSheet: old.sourceSheet, verified: false,
            note: "User-edited draft. Dimension and wall assembly verification still required."
        )
        building = copyBuilding(walls: walls, devices: building.devices)
        persistBuilding()
        message = "Saved wall correction locally; this does not certify field accuracy."
    }

    func updateDevice(_ deviceID: String, xFeet: Double, heightFeet: Double, zFeet: Double) {
        guard let index = building.devices.firstIndex(where: { $0.id == deviceID }) else { return }
        var devices = building.devices
        let old = devices[index]
        devices[index] = ModelDevice(
            id: old.id, kind: old.kind, label: old.label,
            x: xFeet * 0.3048, y: heightFeet * 0.3048, z: zFeet * 0.3048,
            sourceSheet: old.sourceSheet, circuit: old.circuit, verified: false,
            note: "User-positioned provisional marker. Confirm against architectural/electrical coordinates and mounting height."
        )
        building = copyBuilding(walls: building.walls, devices: devices)
        persistBuilding()
        message = "Saved device position locally; this does not certify field accuracy."
    }

    func resetModel() {
        guard let bundled = try? BuildingModel.loadBundled() else { return }
        building = bundled
        try? fm.removeItem(at: editedModelURL)
        message = "Restored original A-201 draft geometry."
    }

    private func copyBuilding(walls: [ModelWall], devices: [ModelDevice]) -> BuildingModel {
        BuildingModel(
            id: building.id, name: building.name, sourceSheet: building.sourceSheet,
            revisionDate: building.revisionDate, widthMeters: building.widthMeters,
            depthMeters: building.depthMeters, description: building.description,
            modelVerified: false, walls: walls, devices: devices, rooms: building.rooms
        )
    }

    private func persistBuilding() {
        guard let bytes = try? JSONEncoder().encode(building) else { return }
        do { try bytes.write(to: editedModelURL, options: .atomic) }
        catch { message = "Couldn't save model edits: \(error.localizedDescription)" }
    }

    func delete(_ drawing: ImportedDrawing) {
        try? fm.removeItem(at: url(for: drawing))
        drawings.removeAll { $0.id == drawing.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(drawings) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}

/// A simple on-device extraction of searchable PDF text. It does NOT understand
/// line geometry, associate electrical symbols with walls, or generate 3D assets.
enum DrawingTextAnalysis {
    struct Result {
        let sheet: String
        let wallTags: [String]
        let references: [String]
        let dimensionCount: Int
    }

    private static func matches(_ regex: String, in string: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return re.matches(in: string, range: range).compactMap {
            Range($0.range, in: string).map { String(string[$0]).uppercased() }
        }
    }

    static func analyze(pdf: PDFDocument, filename: String) -> Result {
        var text = ""
        for i in 0..<min(pdf.pageCount, 60) {
            text += "\n" + (pdf.page(at: i)?.string ?? "")
        }
        let refs = Array(Set(matches(#"\b[A-Z]{1,3}-\d{3}\b"#, in: text))).sorted()
        let tags = Array(Set(matches(#"\b(?:W|M)(?:4|6|8|10)\+?\b"#, in: text))).sorted()
        let dims = matches(#"\d+\s*['′]\s*(?:\d+(?:\s+\d+/\d+)?)?\s*[\"″]?"#, in: text)
        // Only trust a sheet number when the filename itself supplies it.
        // Other matches may be cross-references within the drawing.
        let filenameMatches = matches(#"[A-Z]{1,3}-\d{3}"#, in: filename)
        return Result(sheet: filenameMatches.first ?? "Review sheet ID", wallTags: tags,
                      references: refs, dimensionCount: dims.count)
    }
}
