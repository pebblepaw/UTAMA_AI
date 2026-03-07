import ARKit
import Combine
import Foundation
import RealityKit
import UIKit

final class ARSceneManager: NSObject, ObservableObject {
    @Published var isPlaneDetected: Bool = false
    @Published var areCharactersPlaced: Bool = false

    weak var coordinator: AppCoordinator?

    let characterManager = CharacterManager()

    private(set) weak var arView: ARView?

    private var coachingOverlay: ARCoachingOverlayView?
    private var cameraFacingTimer: Timer?
    private var hasAttemptedPlacement = false

    override init() {
        super.init()

        characterManager.onCharactersPlaced = { [weak self] in
            DispatchQueue.main.async {
                self?.areCharactersPlaced = true
                self?.startCameraFacingUpdates()
                self?.coordinator?.onCharactersPlaced()
            }
        }
    }

    deinit {
        cameraFacingTimer?.invalidate()
    }

    func makeARView(frame: CGRect = .zero) -> ARView {
        if let arView {
            return arView
        }

        let view = ARView(frame: frame)
        view.automaticallyConfigureSession = false
        view.session.delegate = self

        configureSession(for: view)
        setupCoachingOverlay(for: view)
        setupTapPlacement(for: view)

        characterManager.loadCharacters()
        arView = view
        return view
    }

    func updateForState(_ state: AppState) {
        switch state {
        case .conversing:
            startCameraFacingUpdates()
        default:
            stopCameraFacingUpdates()
        }
    }

    private func configureSession(for view: ARView) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic

        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func setupCoachingOverlay(for view: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = view.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = true
        overlay.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        coachingOverlay = overlay
    }

    private func setupTapPlacement(for view: ARView) {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSceneTap(_:)))
        view.addGestureRecognizer(tapRecognizer)
    }

    @objc
    private func handleSceneTap(_ gesture: UITapGestureRecognizer) {
        guard let arView, !areCharactersPlaced else { return }

        let location = gesture.location(in: arView)
        let raycastResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)

        guard let firstResult = raycastResults.first else { return }

        if !isPlaneDetected {
            isPlaneDetected = true
            coordinator?.onPlaneDetected()
        }

        placeCharacters(at: firstResult.worldTransform)
    }

    private func handlePlaneAnchor(_ planeAnchor: ARPlaneAnchor) {
        guard planeAnchor.alignment == .horizontal else { return }

        let planeArea = planeAnchor.extent.x * planeAnchor.extent.z
        guard planeArea >= 0.5 else { return }

        if !isPlaneDetected {
            isPlaneDetected = true
            coordinator?.onPlaneDetected()
        }

        guard !hasAttemptedPlacement, !areCharactersPlaced else { return }
        hasAttemptedPlacement = true

        placeCharacters(at: planeAnchor.transform)
    }

    private func placeCharacters(at worldTransform: simd_float4x4) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: worldTransform)
        arView.scene.addAnchor(anchor)
        characterManager.placeCharacters(on: anchor)

        // Align both characters to face the user camera once at placement time.
        characterManager.faceCharactersTowardCamera(using: arView, smooth: false)
    }

    private func startCameraFacingUpdates() {
        guard cameraFacingTimer == nil else { return }

        cameraFacingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let arView = self.arView else { return }
            self.characterManager.faceCharactersTowardCamera(using: arView, smooth: true)
        }
    }

    private func stopCameraFacingUpdates() {
        cameraFacingTimer?.invalidate()
        cameraFacingTimer = nil
    }
}

extension ARSceneManager: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }

            DispatchQueue.main.async { [weak self] in
                self?.handlePlaneAnchor(planeAnchor)
            }
        }
    }
}
