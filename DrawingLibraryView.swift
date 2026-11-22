import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct DrawingLibraryView: View {
    @ObservedObject var store: ProjectStore
    @State private var showImporter = false
    @State private var selected: ImportedDrawing?

    var body: some View {
        List {
            Section {
                Text("PDFs are copied into this iPhone's private app storage. This view extracts searchable text and symbol references, but it does not yet turn arbitrary PDF drawings into accurate walls or boxes.")
                    .font(.footnote)
                Button {
                    showImporter = true
                } label: {
                    Label("Import PDF Prints", systemImage: "square.and.arrow.down")
                }
                .disabled(store.importing)
                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("Your drawing set") }

            Section("\(store.drawings.count) imported PDF(s)") {
                if store.drawings.isEmpty {
                    Text("No PDFs imported yet. Import A-201, E-104, E-801 or other sheets from Files.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.drawings) { drawing in
                    Button {
                        selected = drawing
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(drawing.sheetNumber).font(.headline)
                                    .foregroundStyle(.primary)
                                Text(drawing.title).font(.caption)
                                    .foregroundStyle(.secondary).lineLimit(1)
                                Text(drawing.summary).font(.caption2)
                                    .foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Text("Suggested order: A-201 (dimensioned walls) → architectural wall sections and elevations → E-104 (power) → E-801 (low voltage) → E-103 (lighting). Check the title block when naming sheets; references inside a PDF are not proof of that PDF's own sheet number.")
                    .font(.footnote)
            } header: { Text("Suggested sheets") }
        }
        .navigationTitle("Drawing Library")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): store.importPDFs(urls)
            case .failure(let error): store.message = error.localizedDescription
            }
        }
        .sheet(item: $selected) { drawing in
            ImportedDrawingDetail(store: store, drawing: drawing)
        }
    }
}

struct ImportedDrawingDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProjectStore
    let drawing: ImportedDrawing
    @State private var sheetName = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFDocumentView(url: store.url(for: drawing))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Sheet number", text: $sheetName)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.roundedBorder)
                            Button("Save") { store.renameSheet(drawing, to: sheetName) }
                                .buttonStyle(.borderedProminent)
                        }
                        Text("Detected wall tags: \(drawing.wallTags.joined(separator: ", "))")
                            .font(.caption)
                        Text("Detected sheet references: \(drawing.sheetReferences.prefix(20).joined(separator: ", "))")
                            .font(.caption)
                        Text("These text matches can include cross-references. No automatic physical wall or device positions have been inferred from this PDF.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding()
                }
                .frame(maxHeight: 185)
            }
            .navigationTitle(drawing.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Delete", role: .destructive) { showDeleteConfirmation = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete the imported copy of this PDF?", isPresented: $showDeleteConfirmation) {
                Button("Delete PDF", role: .destructive) { store.delete(drawing); dismiss() }
            }
            .onAppear { sheetName = drawing.sheetNumber }
        }
    }
}

struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(frame: .zero)
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            view.autoScales = true
        }
    }
}
