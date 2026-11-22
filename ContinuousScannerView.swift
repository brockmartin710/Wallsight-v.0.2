import SwiftUI
import ARKit
import SceneKit
import UIKit
import AVFoundation

struct ContinuousScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scanner = ContinuousScannerController()

    var body: some View {
        ZStack {
            ContinuousARView(controller: scanner).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("WALLSIGHT LIVE")
                            .font(.headline).foregroundStyle(.orange)
                        Text(scanner.status).font(.caption)
                        Text(scanner.trackingWarning).font(.caption)
                            .foregroundStyle(scanner.trackingGood ? .green : .orange)
                        Text("Live mesh sections: \(scanner.meshCount)")
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        scanner.stop(); dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .padding(11).background(.white.opacity(0.15)).clipShape(Circle())
                    }
                }
                .padding()
                .background(.black.opacity(0.72))

                Spacer()

                VStack(spacing: 12) {
                    HStack {
                        Button {
                            scanner.toggleTorch()
                        } label: {
                            Label(scanner.torchOn ? "Flash Off" : "Flash On",
                                  systemImage: scanner.torchOn ? "flashlight.off.fill" : "flashlight.on.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!scanner.isRunning)
                        Spacer()
                        Text("Slow and steady scanning")
                            .font(.caption2)
                    }
                    if !scanner.firstFloorMarked {
                        Text("Scan the first-floor walls before walking upstairs. Keep the session open.")
                            .font(.subheadline).multilineTextAlignment(.center)
                        Button {
                            scanner.markFirstFloor()
                        } label: {
                            Label("Mark First Floor Complete", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!scanner.isRunning)
                    } else {
                        Text("Saved first-floor wall triangles: \(scanner.savedWallTriangles)")
                            .font(.caption)
                        Text("Continue upstairs without stopping the scan. Tracking drift can move these overlays.")
                            .font(.caption).multilineTextAlignment(.center)
                        Button {
                            scanner.toggleWallOverlay()
                        } label: {
                            Label(scanner.showingWalls ? "Show Live Mesh" : "Show Walls Below",
                                  systemImage: "square.3.layers.3d")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Finish Scan") { scanner.stop(); dismiss() }
                        .foregroundStyle(.white)
                    Text("Visual reference only: do not rely on this overlay for drilling.")
                        .font(.caption2).foregroundStyle(.orange)
                }
                .padding()
                .background(.black.opacity(0.79))
            }
            .foregroundStyle(.white)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear { scanner.stop() }
    }
}

struct ContinuousARView: UIViewRepresentable {
    let controller: ContinuousScannerController

    func makeCoordinator() -> ContinuousScannerController { controller }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.session.delegate = controller
        controller.sceneView = view
        controller.start()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    @MainActor static func dismantleUIView(_ uiView: ARSCNView, coordinator: ContinuousScannerController) {
        coordinator.stop()
        uiView.session.pause()
        uiView.session.delegate = nil
    }
}

@MainActor
@Observable
final class ContinuousScannerController: NSObject, ARSessionDelegate {
    var status = "Preparing scanner..."
    var trackingWarning = "Waiting for tracking..."
    var trackingGood = false
    var meshCount = 0
    var savedWallTriangles = 0
    var firstFloorMarked = false
    var showingWalls = false
    var isRunning = false
    var torchOn = false

    weak var sceneView: ARSCNView?
    private var liveNodes: [UUID: SCNNode] = [:]
    private var savedNodes: [SCNNode] = []
    private var latestMeshes: [UUID: ARMeshAnchor] = [:]

    func start() {
        guard let view = sceneView else { return }
        guard ARWorldTrackingConfiguration.isSupported,
              ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            status = "LiDAR scene reconstruction is unavailable."
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        status = "Scanning — move slowly"
    }

    func stop() {
        if torchOn { setTorch(false) }
        isRunning = false
        sceneView?.session.pause()
        sceneView?.session.delegate = nil
        status = "Scan stopped"
    }

    func toggleTorch() { setTorch(!torchOn) }

    private func setTorch(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            status = "Torch unavailable on this camera."
            torchOn = false
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = enabled ? .on : .off
            torchOn = enabled
            status = enabled ? "Flash on — scan slowly" : "Flash off — scanning"
        } catch {
            torchOn = false
            status = "Flash control blocked: \(error.localizedDescription)"
        }
    }

    func markFirstFloor() {
        guard isRunning, !firstFloorMarked, let view = sceneView else { return }
        if let anchors = view.session.currentFrame?.anchors {
            for anchor in anchors {
                if let mesh = anchor as? ARMeshAnchor { latestMeshes[mesh.identifier] = mesh }
            }
        }
        var newNodes: [SCNNode] = []
        var total = 0
        for mesh in latestMeshes.values {
            let result = makeGeometry(from: mesh, wallsOnly: true, color: .orange)
            guard result.triangleCount > 0 else { continue }
            let node = SCNNode(geometry: result.geometry)
            node.simdTransform = mesh.transform
            node.isHidden = true
            view.scene.rootNode.addChildNode(node)
            newNodes.append(node)
            total += result.triangleCount
        }
        guard total > 0 else {
            status = "No classified walls yet — scan more slowly."
            return
        }
        savedNodes = newNodes
        savedWallTriangles = total
        firstFloorMarked = true
        status = "First floor captured — DO NOT restart AR session."
    }

    func toggleWallOverlay() {
        guard firstFloorMarked else { return }
        showingWalls.toggle()
        for n in liveNodes.values { n.isHidden = showingWalls }
        for n in savedNodes { n.isHidden = !showingWalls }
        status = showingWalls ? "Orange saved walls" : "Cyan live mesh"
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in self.updateMeshes(anchors) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in self.updateMeshes(anchors) }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let identifiers = anchors.map(\.identifier)
        Task { @MainActor in
            for id in identifiers {
                self.liveNodes[id]?.removeFromParentNode()
                self.liveNodes.removeValue(forKey: id)
                self.latestMeshes.removeValue(forKey: id)
            }
            self.meshCount = self.liveNodes.count
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let good: Bool
        let warning: String
        switch camera.trackingState {
        case .normal:
            good = true; warning = "Tracking normal"
        case .notAvailable:
            good = false; warning = "Tracking unavailable"
        case .limited:
            good = false; warning = "Tracking LIMITED — move slowly; walls can drift"
        }
        Task { @MainActor in
            self.trackingGood = good
            self.trackingWarning = warning
        }
    }

    private func updateMeshes(_ anchors: [ARAnchor]) {
        guard isRunning, let view = sceneView else { return }
        for anchor in anchors {
            guard let mesh = anchor as? ARMeshAnchor else { continue }
            latestMeshes[mesh.identifier] = mesh
            let result = makeGeometry(from: mesh, wallsOnly: false, color: .cyan)
            if let old = liveNodes[mesh.identifier] {
                old.geometry = result.geometry
                old.simdTransform = mesh.transform
                old.isHidden = showingWalls
            } else {
                let node = SCNNode(geometry: result.geometry)
                node.simdTransform = mesh.transform
                node.isHidden = showingWalls
                view.scene.rootNode.addChildNode(node)
                liveNodes[mesh.identifier] = node
            }
        }
        meshCount = liveNodes.count
    }

    private func classification(for face: Int, in mesh: ARMeshGeometry) -> ARMeshClassification {
        guard let source = mesh.classification, face >= 0, face < source.count else { return .none }
        let pointer = source.buffer.contents().advanced(by: source.offset + face * source.stride)
        let raw = pointer.load(as: UInt8.self)
        return ARMeshClassification(rawValue: Int(raw)) ?? .none
    }

    private func makeGeometry(from anchor: ARMeshAnchor, wallsOnly: Bool, color: UIColor)
        -> (geometry: SCNGeometry, triangleCount: Int) {
        let mesh = anchor.geometry
        let verts = mesh.vertices
        let faces = mesh.faces
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        vertices.reserveCapacity(verts.count)
        for i in 0..<verts.count {
            let p = verts.buffer.contents().advanced(by: verts.offset + i * verts.stride)
            let v = p.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            vertices.append(SCNVector3(v.x, v.y, v.z))
        }
        for face in 0..<faces.count {
            if wallsOnly && classification(for: face, in: mesh) != .wall { continue }
            let facePointer = faces.buffer.contents().advanced(
                by: face * faces.indexCountPerPrimitive * faces.bytesPerIndex)
            for vertexIndex in 0..<faces.indexCountPerPrimitive {
                let p = facePointer.advanced(by: vertexIndex * faces.bytesPerIndex)
                let value: Int32 = faces.bytesPerIndex == 2
                    ? Int32(p.loadUnaligned(as: UInt16.self))
                    : Int32(bitPattern: p.loadUnaligned(as: UInt32.self))
                indices.append(value)
            }
        }
        let src = SCNGeometrySource(vertices: vertices)
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let elem = SCNGeometryElement(data: idxData, primitiveType: .triangles,
                                       primitiveCount: indices.count / 3,
                                       bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [src], elements: [elem])
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(wallsOnly ? 0.85 : 0.45)
        material.fillMode = .lines
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.readsFromDepthBuffer = !wallsOnly
        material.writesToDepthBuffer = false
        geometry.materials = [material]
        return (geometry, indices.count / 3)
    }
}
