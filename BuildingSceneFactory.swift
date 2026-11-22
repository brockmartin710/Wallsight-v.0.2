import Foundation
import SceneKit
import UIKit

/// Shared 3D geometry for the off-site viewer and the on-site AR preview.
/// The model's positive X follows A-201 left-to-right; positive Z follows top-to-bottom.
enum BuildingSceneFactory {
    static func createModelRoot(_ model: BuildingModel, showFloor: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = "buildingRoot"

        if showFloor {
            let floor = SCNPlane(width: CGFloat(model.widthMeters + 2), height: CGFloat(model.depthMeters + 4))
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 0.22, green: 0.27, blue: 0.31, alpha: 1)
            material.lightingModel = .constant
            material.isDoubleSided = true
            floor.materials = [material]
            let n = SCNNode(geometry: floor)
            n.name = "floor"
            n.eulerAngles.x = -.pi / 2
            n.position = SCNVector3(Float(model.widthMeters / 2), -0.015, Float(model.depthMeters / 2))
            root.addChildNode(n)
        }

        for wall in model.walls {
            let length = wall.lengthMeters
            guard length > 0.01 else { continue }
            let geometry = SCNBox(
                width: CGFloat(length),
                height: CGFloat(wall.heightMeters),
                length: CGFloat(wall.thicknessMeters),
                chamferRadius: 0
            )
            let m = SCNMaterial()
            // Different framing families are recognizable in the 3D prototype.
            m.diffuse.contents = wall.tag.hasPrefix("M")
                ? UIColor(red: 0.34, green: 0.68, blue: 0.95, alpha: 1)
                : UIColor(red: 0.44, green: 0.77, blue: 0.71, alpha: 1)
            m.transparency = 0.61
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.writesToDepthBuffer = false
            geometry.materials = [m]

            let node = SCNNode(geometry: geometry)
            node.name = "wall:\(wall.id)"
            node.position = SCNVector3(
                Float((wall.start.x + wall.end.x) / 2),
                Float(wall.heightMeters / 2),
                Float((wall.start.z + wall.end.z) / 2)
            )
            // A box's long axis is local X; rotate that axis to the plan segment.
            node.eulerAngles.y = Float(-atan2(wall.end.z - wall.start.z,
                                              wall.end.x - wall.start.x))
            root.addChildNode(node)
        }

        for device in model.devices {
            let panel = device.kind == "panel"
            let geometry = SCNBox(
                width: panel ? 0.55 : 0.22,
                height: panel ? 0.85 : 0.22,
                length: 0.12,
                chamferRadius: 0.015
            )
            let m = SCNMaterial()
            switch device.kind {
            case "panel": m.diffuse.contents = UIColor.systemRed
            case "lowVoltage": m.diffuse.contents = UIColor.systemPurple
            case "switch": m.diffuse.contents = UIColor.systemYellow
            default: m.diffuse.contents = UIColor.systemOrange
            }
            m.lightingModel = .constant
            geometry.materials = [m]
            let n = SCNNode(geometry: geometry)
            n.name = "device:\(device.id)"
            n.position = SCNVector3(Float(device.x), Float(device.y), Float(device.z))
            root.addChildNode(n)
        }

        if showFloor {
            for room in model.rooms {
                let txt = SCNText(string: room.name, extrusionDepth: 0)
                txt.font = UIFont.boldSystemFont(ofSize: 0.45)
                txt.flatness = 0.03
                let m = SCNMaterial()
                m.diffuse.contents = UIColor.white
                m.lightingModel = .constant
                m.isDoubleSided = true
                txt.materials = [m]
                let n = SCNNode(geometry: txt)
                n.name = "room:\(room.name)"
                n.eulerAngles.x = -.pi / 2
                n.position = SCNVector3(Float(room.x), 0.03, Float(room.z))
                root.addChildNode(n)
            }
        }

        let origin = SCNCylinder(radius: 0.17, height: 0.025)
        origin.firstMaterial?.diffuse.contents = UIColor.systemGreen
        let marker = SCNNode(geometry: origin)
        marker.name = "originMarker"
        marker.position = SCNVector3(0, 0.025, 0)
        root.addChildNode(marker)
        return root
    }

    static func setVisibility(root: SCNNode?, walls: Bool, electrical: Bool, rooms: Bool = true) {
        root?.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            if name.hasPrefix("wall:") { node.isHidden = !walls }
            if name.hasPrefix("device:") { node.isHidden = !electrical }
            if name.hasPrefix("room:") { node.isHidden = !rooms }
        }
    }
}
