import Foundation
import SceneKit

struct PlanPoint: Codable, Equatable {
    var x: Double
    var z: Double
}

struct ModelWall: Codable, Identifiable {
    let id: String
    let tag: String
    let start: PlanPoint
    let end: PlanPoint
    let thicknessMeters: Double
    let heightMeters: Double
    let sourceSheet: String
    let verified: Bool
    let note: String

    var lengthMeters: Double {
        hypot(end.x - start.x, end.z - start.z)
    }
}

struct ModelDevice: Codable, Identifiable {
    let id: String
    let kind: String
    let label: String
    let x: Double
    let y: Double
    let z: Double
    let sourceSheet: String
    let circuit: String
    let verified: Bool
    let note: String
}

struct ModelRoom: Codable, Identifiable {
    let name: String
    let x: Double
    let z: Double
    var id: String { name }
}

struct BuildingModel: Codable, Identifiable {
    let id: String
    let name: String
    let sourceSheet: String
    let revisionDate: String
    let widthMeters: Double
    let depthMeters: Double
    let description: String
    let modelVerified: Bool
    let walls: [ModelWall]
    let devices: [ModelDevice]
    let rooms: [ModelRoom]

    var widthFeet: Double { widthMeters / 0.3048 }
    var depthFeet: Double { depthMeters / 0.3048 }

    static func loadBundled() throws -> BuildingModel {
        guard let url = Bundle.main.url(forResource: "HeathChickFilA_DRAFT", withExtension: "json") else {
            throw NSError(domain: "WallSight", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled model JSON not found. Check project.yml resources."])
        }
        return try JSONDecoder().decode(BuildingModel.self, from: Data(contentsOf: url))
    }

    static let empty = BuildingModel(
        id: "missing-data", name: "Model unavailable", sourceSheet: "Unknown",
        revisionDate: "", widthMeters: 10, depthMeters: 10,
        description: "The A-201 draft model was not bundled. Check resources.",
        modelVerified: false, walls: [], devices: [], rooms: []
    )
}

extension Double {
    var feetAndInches: String {
        let totalInches = Int((self / 0.0254).rounded())
        return "\(totalInches / 12)′ \(totalInches % 12)″"
    }
}
