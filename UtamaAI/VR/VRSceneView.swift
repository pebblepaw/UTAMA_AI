import AVKit
import CoreMotion
import SceneKit
import SwiftUI

/// AR-overlay curved cinema view: video appears on a curved screen while AR background remains visible.
struct VRSceneView: View {
    @ObservedObject var vrPlayer: VRScenePlayer

    var body: some View {
        if let player = vrPlayer.avPlayer {
            ARCurvedScreenContainer(player: player)
                .ignoresSafeArea()
        } else {
            VStack(spacing: 16) {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                Text("VR scene video not found")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Add lion_encounter_vr.mp4 to Assets/Video/")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

private struct ARCurvedScreenContainer: UIViewRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.rendersContinuously = true
        scnView.allowsCameraControl = false

        let scene = SCNScene()
        scnView.scene = scene

        let sharedMaterial = SCNMaterial()
        sharedMaterial.diffuse.contents = player
        sharedMaterial.isDoubleSided = false
        sharedMaterial.lightingModel = .constant

        // Use original video mapping with no forced crop transforms.
        sharedMaterial.diffuse.contentsTransform = SCNMatrix4Identity

        // Single slightly curved screen (no side panels).
        // 16:9 panel avoids additional letterboxing from aspect mismatch.
        let centerPlane = SCNPlane(width: 7.2, height: 4.05)
        centerPlane.firstMaterial = sharedMaterial
        let centerNode = SCNNode(geometry: centerPlane)
        centerNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(centerNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 9.5)
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        context.coordinator.startMotionUpdates(cameraNode: cameraNode)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let nodes = uiView.scene?.rootNode.childNodes else { return }
        for node in nodes {
            guard let material = node.geometry?.firstMaterial else { continue }
            if material.diffuse.contents as AnyObject? !== player {
                material.diffuse.contents = player
            }
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopMotionUpdates()
    }

    final class Coordinator {
        private let motionManager = CMMotionManager()
        private var initialYaw: Double?
        private var initialPitch: Double?
        private weak var cameraNode: SCNNode?

        func startMotionUpdates(cameraNode: SCNNode) {
            self.cameraNode = cameraNode
            initialYaw = nil
            initialPitch = nil

            guard motionManager.isDeviceMotionAvailable else { return }
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, _ in
                guard let self, let motion, let cameraNode = self.cameraNode else { return }
                if self.initialYaw == nil {
                    self.initialYaw = motion.attitude.yaw
                    self.initialPitch = motion.attitude.pitch
                }
                guard let initialYaw = self.initialYaw, let initialPitch = self.initialPitch else { return }

                let deltaYaw = Float(motion.attitude.yaw - initialYaw)
                let deltaPitch = Float(motion.attitude.pitch - initialPitch)
                let clampedPitch = max(min(deltaPitch, 0.45), -0.45)
                // Inverse mapping keeps panel fixed in AR-like world space relative to user motion.
                cameraNode.eulerAngles = SCNVector3(-clampedPitch, -deltaYaw, 0)
            }
        }

        func stopMotionUpdates() {
            motionManager.stopDeviceMotionUpdates()
            initialYaw = nil
            initialPitch = nil
            cameraNode = nil
        }
    }
}
