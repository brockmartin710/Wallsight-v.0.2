import SwiftUI
import UniformTypeIdentifiers

struct ModelEditorView: View {
    @ObservedObject var store: ProjectStore
    @State private var selectedTab = "Walls"
    @State private var showReset = false
    @State private var showModelImporter = false

    var body: some View {
        List {
            Section {
                Text("All coordinates are in FEET, measured from the draft A-201 plan origin (upper-left drawing reference). +X goes right; +Z goes down. Wall heights and exact wall endpoints are estimates until checked against dimension strings and elevations.")
                    .font(.footnote)
                if !store.message.isEmpty {
                    Text(store.message).font(.caption).foregroundStyle(.secondary)
                }
                Button("Import generated 3D model (.json)") { showModelImporter = true }
                Button("Reset all corrections", role: .destructive) { showReset = true }
            } header: { Text("Coordinate reference") }

            Section {
                Picker("Edit", selection: $selectedTab) {
                    Text("Walls").tag("Walls")
                    Text("Devices").tag("Devices")
                }.pickerStyle(.segmented)
            }

            if selectedTab == "Walls" {
                Section("\(store.building.walls.count) wall segments") {
                    ForEach(store.building.walls) { wall in
                        NavigationLink {
                            WallEditDetail(store: store, wall: wall)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(wall.id) — \(wall.tag)")
                                Text(String(format: "Approx. %.1f ft • A-201", wall.lengthMeters / 0.3048))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Section("\(store.building.devices.count) provisional markers") {
                    ForEach(store.building.devices) { dev in
                        NavigationLink {
                            DeviceEditDetail(store: store, device: dev)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(dev.label)
                                Text("\(dev.id) • \(dev.sourceSheet) • unverified")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Model Corrections")
        .fileImporter(isPresented: $showModelImporter,
                      allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { store.importModelJSON(url) }
            case .failure(let error): store.message = error.localizedDescription
            }
        }
        .confirmationDialog("Reset all model edits?", isPresented: $showReset) {
            Button("Reset Draft", role: .destructive) { store.resetModel() }
        }
    }
}

struct WallEditDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProjectStore
    let wall: ModelWall
    @State private var x1 = ""
    @State private var z1 = ""
    @State private var x2 = ""
    @State private var z2 = ""
    @State private var height = ""

    var body: some View {
        Form {
            Section("Wall \(wall.id) • \(wall.tag) framing") {
                number("Start X (feet)", value: $x1)
                number("Start Z (feet)", value: $z1)
                number("End X (feet)", value: $x2)
                number("End Z (feet)", value: $z2)
                number("Wall height (feet)", value: $height)
            }
            Section {
                Button("Save wall changes") {
                    guard let a = Double(x1), let b = Double(z1), let c = Double(x2),
                          let d = Double(z2), let h = Double(height), h > 0 else { return }
                    store.updateWall(wall.id, startXFeet: a, startZFeet: b,
                                     endXFeet: c, endZFeet: d, heightFeet: h)
                    dismiss()
                }
                Text("Saved adjustments remain marked unverified until checked against the complete construction set.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(wall.id)
        .onAppear {
            x1 = String(format: "%.2f", wall.start.x / 0.3048)
            z1 = String(format: "%.2f", wall.start.z / 0.3048)
            x2 = String(format: "%.2f", wall.end.x / 0.3048)
            z2 = String(format: "%.2f", wall.end.z / 0.3048)
            height = String(format: "%.2f", wall.heightMeters / 0.3048)
        }
    }

    private func number(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 105)
        }
    }
}

struct DeviceEditDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProjectStore
    let device: ModelDevice
    @State private var x = ""
    @State private var y = ""
    @State private var z = ""

    var body: some View {
        Form {
            Section(device.label) {
                number("X from origin (feet)", value: $x)
                number("Height above slab (feet)", value: $y)
                number("Z from origin (feet)", value: $z)
            }
            Section {
                Button("Save device position") {
                    guard let a = Double(x), let b = Double(y), let c = Double(z) else { return }
                    store.updateDevice(device.id, xFeet: a, heightFeet: b, zFeet: c)
                    dismiss()
                }
                Text("Recheck device symbol, dimension, mounting height, source sheet and latest revisions before using any model location on-site.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(device.id)
        .onAppear {
            x = String(format: "%.2f", device.x / 0.3048)
            y = String(format: "%.2f", device.y / 0.3048)
            z = String(format: "%.2f", device.z / 0.3048)
        }
    }

    private func number(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 105)
        }
    }
}
