import SwiftUI
import SceneKit
import UIKit

struct InspectSelection: Identifiable {
    let id: String
    let category: String
}

struct BuildingViewerView: View {
    let building: BuildingModel
    @StateObject private var controller = BuildingViewerController()
    @State private var mode = "Overview"
    @State private var showWalls = true
    @State private var showElectrical = true
    @State private var showRooms = true
    @State private var selection: InspectSelection?

    var body: some View {
        VStack(spacing: 7) {
            Picker("Navigation", selection: $mode) {
                Text("3D Overview").tag("Overview")
                Text("Walkthrough").tag("Walkthrough")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)

            BuildingSceneView(
                building: building, controller: controller, mode: mode,
                showWalls: showWalls, showElectrical: showElectrical,
                showRooms: showRooms, selection: $selection
            )
            .overlay(alignment: .topLeading) {
                Text("A-201 DRAFT · not survey-verified")
                    .font(.caption2.bold()).padding(8)
                    .foregroundStyle(.white).background(.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                if mode == "Walkthrough" {
                    VStack(spacing: 5) {
                        Text("Tap arrows to move. No wall collisions yet.")
                            .font(.caption2).foregroundStyle(.white)
                        HStack(spacing: 14) {
                            Button { controller.move("left") } label: { Image(systemName: "arrow.turn.up.left") }
                            Button { controller.move("forward") } label: { Image(systemName: "arrow.up") }
                            Button { controller.move("backward") } label: { Image(systemName: "arrow.down") }
                            Button { controller.move("right") } label: { Image(systemName: "arrow.turn.up.right") }
                            Button { controller.resetWalk() } label: { Image(systemName: "arrow.counterclockwise") }
                        }
                        .font(.title3)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(12)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(10)
                }
            }

            HStack(spacing: 13) {
                Toggle("Walls", isOn: $showWalls)
                Toggle("Devices", isOn: $showElectrical)
                Toggle("Rooms", isOn: $showRooms)
            }
            .font(.caption2)
            .padding(.horizontal, 10)

            HStack {
                Text("123′6″ × 47′8″ overall reference dimensions")
                Spacer()
                Text("\(building.walls.count) walls")
            }
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.bottom, 5)
        }
        .navigationTitle("Heath 3D Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selection) { item in
            inspector(item)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func inspector(_ item: InspectSelection) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if item.category == "wall", let wall = building.walls.first(where: { $0.id == item.id }) {
                        Text("Wall \(wall.id)").font(.title2.bold())
                        LabeledContent("Framing type", value: wall.tag)
                        LabeledContent("Length (approx.)", value: wall.lengthMeters.feetAndInches)
                        LabeledContent("Nominal frame depth", value: wall.thicknessMeters.feetAndInches)
                        LabeledContent("Assumed wall height", value: wall.heightMeters.feetAndInches)
                        LabeledContent("Source", value: wall.sourceSheet)
                        Text(wall.note)
                            .font(.callout).foregroundStyle(.orange)
                    } else if item.category == "device", let dev = building.devices.first(where: { $0.id == item.id }) {
                        Text(dev.label).font(.title2.bold())
                        LabeledContent("Device", value: dev.kind)
                        LabeledContent("Circuit", value: dev.circuit)
                        LabeledContent("Height in model", value: dev.y.feetAndInches)
                        LabeledContent("Source", value: dev.sourceSheet)
                        Text(dev.note).font(.callout).foregroundStyle(.orange)
                    }
                    Label("Coordinates are not approved for field layout.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                .padding()
            }
            .navigationTitle("Model Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { selection = nil } } }
        }
    }
}

@MainActor
final class BuildingViewerController: ObservableObject {
    weak var sceneView: SCNView?
    var modelRoot: SCNNode?
    var overviewCamera: SCNNode?
    var walkCamera: SCNNode?
    private var currentMode = ""
    private var initialWalkPosition = SCNVector3(7, 1.65, 8)

    func prepare(_ view: SCNView, building: BuildingModel) {
        let scene = SCNScene()
        let root = BuildingSceneFactory.createModelRoot(building, showFloor: true)
        scene.rootNode.addChildNode(root)
        modelRoot = root

        let overview = SCNNode()
        overview.camera = SCNCamera()
        overview.camera?.zFar = 250
        overview.position = SCNVector3(Float(building.widthMeters * 0.5),
                                       Float(max(building.widthMeters, building.depthMeters) * 0.74),
                                       Float(building.depthMeters * 1.9))
        overview.look(at: SCNVector3(Float(building.widthMeters / 2), 0,
                                     Float(building.depthMeters / 2)))
        scene.rootNode.addChildNode(overview)
        overviewCamera = overview

        let walk = SCNNode()
        walk.camera = SCNCamera()
        walk.camera?.zFar = 140
        initialWalkPosition = SCNVector3(7, 1.65, 8)
        walk.position = initialWalkPosition
        walk.eulerAngles.y = -.pi / 2
        scene.rootNode.addChildNode(walk)
        walkCamera = walk

        view.scene = scene
        view.pointOfView = overview
        view.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        sceneView = view
    }

    func configure(mode: String, walls: Bool, devices: Bool, rooms: Bool) {
        if mode != currentMode {
            sceneView?.allowsCameraControl = (mode == "Overview")
            sceneView?.pointOfView = (mode == "Walkthrough") ? walkCamera : overviewCamera
            currentMode = mode
        }
        BuildingSceneFactory.setVisibility(root: modelRoot, walls: walls,
                                           electrical: devices, rooms: rooms)
    }

    func resetWalk() {
        walkCamera?.position = initialWalkPosition
        walkCamera?.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
    }

    func move(_ command: String) {
        guard currentMode == "Walkthrough", let camera = walkCamera else { return }
        let yaw = camera.eulerAngles.y
        let step: Float = 0.6
        switch command {
        case "left": camera.eulerAngles.y += Float.pi / 12
        case "right": camera.eulerAngles.y -= Float.pi / 12
        case "forward":
            camera.position.x -= sin(yaw) * step
            camera.position.z -= cos(yaw) * step
        case "backward":
            camera.position.x += sin(yaw) * step
            camera.position.z += cos(yaw) * step
        default: break
        }
        camera.position.y = 1.65
    }
}

struct BuildingSceneView: UIViewRepresentable {
    let building: BuildingModel
    @ObservedObject var controller: BuildingViewerController
    let mode: String
    let showWalls: Bool
    let showElectrical: Bool
    let showRooms: Bool
    @Binding var selection: InspectSelection?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        controller.prepare(view, building: building)
        let recognizer = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.onTap(_:)))
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        controller.configure(mode: mode, walls: showWalls,
                             devices: showElectrical, rooms: showRooms)
    }

    final class Coordinator: NSObject {
        var parent: BuildingSceneView
        init(parent: BuildingSceneView) { self.parent = parent }

        @objc func onTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            for hit in view.hitTest(gesture.location(in: view), options: nil) {
                var current: SCNNode? = hit.node
                while let node = current {
                    if let name = node.name, name.hasPrefix("device:") {
                        parent.selection = InspectSelection(id: String(name.dropFirst(7)), category: "device")
                        return
                    }
                    if let name = node.name, name.hasPrefix("wall:") {
                        parent.selection = InspectSelection(id: String(name.dropFirst(5)), category: "wall")
                        return
                    }
                    current = node.parent
                }
            }
        }
    }
}
