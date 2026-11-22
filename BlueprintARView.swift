import SwiftUI
import ARKit
import SceneKit
import simd

struct BlueprintARView: View {
    let building: BuildingModel
    @StateObject private var controller: BlueprintARController

    init(building: BuildingModel) {
        self.building = building
        _controller = StateObject(wrappedValue: BlueprintARController(building: building))
    }

    var body: some View {
        ZStack {
            if ARWorldTrackingConfiguration.isSupported {
                BlueprintARScene(controller: controller).ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BLUEPRINT AR — PREVIEW ONLY")
                            .font(.headline).foregroundStyle(.orange)
                        Text(controller.trackingText)
                            .font(.caption)
                        Text(controller.message)
                            .font(.caption)
                        Text("Wall geometry and devices are unverified. Never use this display to place conduit or drill without field measurements.")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.black.opacity(0.75))
                    .foregroundStyle(.white)

                    Spacer()

                    VStack(spacing: 8) {
                        HStack {
                            Toggle("Walls", isOn: $controller.showWalls)
                            Toggle("Devices", isOn: $controller.showDevices)
                        }
                        .font(.caption)
                        .onChange(of: controller.showWalls) { _, _ in controller.applyVisibility() }
                        .onChange(of: controller.showDevices) { _, _ in controller.applyVisibility() }

                        HStack {
                            Text("Reference spacing")
                            Spacer()
                            Text("\(Int(controller.referenceFeet)) ft")
                        }.font(.caption)
                        Slider(value: $controller.referenceFeet, in: 5...120, step: 1)

                        HStack(spacing: 10) {
                            Button("1. Mark Corner A") { controller.markA() }
                                .buttonStyle(.borderedProminent)
                            Button("2. Mark Point B") { controller.markB() }
                                .buttonStyle(.borderedProminent)
                        }
                        .font(.caption)
                        Text("Stand at the northwest plan origin for A. For B, stand at a second measured point exactly \(Int(controller.referenceFeet)) ft along A-201's positive X (left-to-right) direction. Keep tracking uninterrupted.")
                            .font(.caption2)

                        HStack {
                            Text("Manual yaw")
                            Slider(value: $controller.yawOffsetDegrees, in: -20...20, step: 1)
                                .onChange(of: controller.yawOffsetDegrees) { _, _ in controller.updateAlignment() }
                            Text("\(Int(controller.yawOffsetDegrees))°")
                        }.font(.caption)
                        HStack {
                            Text("Camera height")
                            Slider(value: $controller.cameraHeightMeters, in: 1.0...2.0, step: 0.05)
                                .onChange(of: controller.cameraHeightMeters) { _, _ in controller.updateAlignment() }
                            Text(String(format: "%.2f m", controller.cameraHeightMeters))
                        }.font(.caption)

                        Button("Reset Alignment") { controller.resetAlignment() }
                            .font(.caption)
                    }
                    .padding(12)
                    .background(.black.opacity(0.8))
                    .foregroundStyle(.white)
                }
            } else {
                ContentUnavailableView("AR Unavailable", systemImage: "iphone.slash",
                                       description: Text("ARKit world tracking is not supported on this device."))
            }
        }
        .navigationTitle("Blueprint AR")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onDisappear { controller.stop() }
    }
}

struct BlueprintARScene: UIViewRepresentable {
    @ObservedObject var controller: BlueprintARController

    func makeCoordinator() -> BlueprintARController { controller }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.session.delegate = controller
        controller.start(on: view)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {}

    @MainActor static func dismantleUIView(_ view: ARSCNView, coordinator: BlueprintARController) {
        coordinator.stop()
        view.session.delegate = nil
    }
}

@MainActor
final class BlueprintARController: NSObject, ObservableObject, ARSessionDelegate {
    @Published var message = "Move slowly until tracking is stable."
    @Published var trackingText = "Tracking initializing..."
    @Published var showWalls = true
    @Published var showDevices = true
    @Published var referenceFeet = 20.0
    @Published var yawOffsetDegrees = 0.0
    @Published var cameraHeightMeters = 1.5

    private let building: BuildingModel
    weak var sceneView: ARSCNView?
    private var buildingRoot: SCNNode?
    private var cornerA: SIMD3<Float>?
    private var cornerB: SIMD3<Float>?

    init(building: BuildingModel) { self.building = building; super.init() }

    func start(on view: ARSCNView) {
        guard ARWorldTrackingConfiguration.isSupported else { return }
        sceneView = view
        let root = BuildingSceneFactory.createModelRoot(building, showFloor: false)
        root.isHidden = true
        view.scene.rootNode.addChildNode(root)
        buildingRoot = root
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        message = "Mark two known reference points to place the model."
    }

    func stop() {
        sceneView?.session.pause()
        sceneView?.session.delegate = nil
        sceneView = nil
    }

    private func cameraPosition() -> SIMD3<Float>? {
        guard let frame = sceneView?.session.currentFrame else {
            message = "AR tracking not initialized."
            return nil
        }
        guard case .normal = frame.camera.trackingState else {
            message = "Tracking is limited. Move slowly and wait for normal tracking."
            return nil
        }
        let p = frame.camera.transform.columns.3
        return SIMD3<Float>(p.x, p.y, p.z)
    }

    func markA() {
        guard let p = cameraPosition() else { return }
        cornerA = p
        cornerB = nil
        buildingRoot?.isHidden = true
        message = "A captured. Move \(Int(referenceFeet)) measured feet along the A-201 X axis, then mark B."
    }

    func markB() {
        guard cornerA != nil else { message = "Mark A first."; return }
        guard let p = cameraPosition() else { return }
        cornerB = p
        updateAlignment()
    }

    func updateAlignment() {
        guard let a = cornerA, let b = cornerB, let root = buildingRoot else { return }
        let dx = b.x - a.x
        let dz = b.z - a.z
        let actual = Double(hypot(dx, dz))
        let expected = referenceFeet * 0.3048
        if actual < 1 {
            message = "Reference points too close. Re-mark B at a distinct measured location."
            root.isHidden = true
            return
        }
        // Keep model's scale fixed at 1:1. Report disagreement instead of silently stretching it.
        let yaw = -atan2(Double(dz), Double(dx)) + yawOffsetDegrees * .pi / 180
        root.eulerAngles.y = Float(yaw)
        root.position = SCNVector3(a.x, a.y - Float(cameraHeightMeters), a.z)
        root.isHidden = false
        applyVisibility()
        let deviation = abs(actual - expected)
        message = String(format: "Aligned. Measured %.2f m, drawing %.2f m; mismatch %.2f m. %@",
                         actual, expected, deviation,
                         deviation > 0.25 ? "CHECK REFERENCE POINTS / TRACKING." : "Reference spacing close.")
    }

    func resetAlignment() {
        cornerA = nil
        cornerB = nil
        buildingRoot?.isHidden = true
        yawOffsetDegrees = 0
        message = "Alignment cleared. Mark reference point A again."
    }

    func applyVisibility() {
        BuildingSceneFactory.setVisibility(root: buildingRoot, walls: showWalls,
                                           electrical: showDevices, rooms: false)
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let text: String
        switch camera.trackingState {
        case .normal: text = "Tracking normal"
        case .notAvailable: text = "Tracking unavailable"
        case .limited: text = "Tracking limited — move slowly; results may drift"
        }
        Task { @MainActor in self.trackingText = text }
    }
}
