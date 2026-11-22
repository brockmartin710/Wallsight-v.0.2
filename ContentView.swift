import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.largeTitle).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WALLSIGHT").font(.largeTitle.bold())
                            Text("BLUEPRINTS • 3D • AR • LiDAR").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Heath Chick-fil-A").font(.title2.bold())
                        Text("Draft model traced from architectural sheet A-201")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(store.building.walls.count) wall segments • \(store.building.devices.count) provisional device markers")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("REFERENCE ONLY — NOT VERIFIED FOR LAYOUT OR DRILLING")
                            .font(.caption.bold()).foregroundStyle(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    NavigationLink {
                        BuildingViewerView(building: store.building)
                    } label: {
                        feature("3D Building & Walkthrough", "Orbit, zoom, walk virtually, inspect electrical markers.", "cube.transparent")
                    }
                    NavigationLink {
                        BlueprintARView(building: store.building)
                    } label: {
                        feature("Blueprint AR", "Preview plan walls over the camera using two reference positions.", "arkit")
                    }
                    NavigationLink {
                        ModelEditorView(store: store)
                    } label: {
                        feature("Correct Model Positions", "Edit wall endpoints and marker coordinates in feet.", "ruler")
                    }
                    NavigationLink {
                        DrawingLibraryView(store: store)
                    } label: {
                        feature("PDF Drawing Library", "Import PDFs, examine sheets, and detect tags and references.", "doc.text.magnifyingglass")
                    }
                    NavigationLink {
                        HouseScanView()
                    } label: {
                        feature("LiDAR House Scanner", "Scan first-floor mesh, mark walls, view from upstairs.", "viewfinder")
                    }

                    if !store.message.isEmpty {
                        Text(store.message).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("PDF importing and text scanning are working prototype features. Automatic cross-sheet PDF-to-BIM conversion and drill-point precision are NOT implemented.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Projects")
        }
        .tint(.orange)
    }

    private func feature(_ name: String, _ desc: String, _ symbol: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.title2).foregroundStyle(.orange).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.headline).foregroundStyle(.primary)
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
