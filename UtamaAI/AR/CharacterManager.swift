import AVFoundation
import Combine
import Foundation
import RealityKit
import UIKit

enum CharacterAnimationState {
    case idle
    case talking
    case roaring
    case gesturing
}

final class CharacterManager: ObservableObject {
    @Published private(set) var utamaEntity: ModelEntity?
    @Published private(set) var lionEntity: ModelEntity?

    var onCharactersPlaced: (() -> Void)?

    private var animationStates: [Character: CharacterAnimationState] = [:]
    private var targetScales: [Character: SIMD3<Float>] = [:]
    private var spawnSFXPlayer: AVAudioPlayer?

    func loadCharacters() {
        if utamaEntity == nil {
            utamaEntity = loadModelEntity(
                named: "utama",
                fallbackMesh: .generateBox(size: 0.25),
                fallbackColor: .systemTeal
            )
            utamaEntity?.name = "utama"
        }

        if lionEntity == nil {
            lionEntity = loadModelEntity(
                named: "lion",
                fallbackMesh: .generateSphere(radius: 0.2),
                fallbackColor: .systemOrange
            )
            lionEntity?.name = "lion"
        }
    }

    func placeCharacters(on anchor: AnchorEntity) {
        loadCharacters()

        guard let utamaEntity, let lionEntity else { return }

        if utamaEntity.parent == nil {
            anchor.addChild(utamaEntity)
        }
        if lionEntity.parent == nil {
            anchor.addChild(lionEntity)
        }

        utamaEntity.position = [0, 0, 0]
        lionEntity.position = [0.8, 0, 0]

        scaleEntity(utamaEntity, toApproximateHeight: 1.5, for: .utama)
        scaleEntity(lionEntity, toApproximateHeight: 0.9, for: .lion)

        spawnCharacter(.utama, on: anchor)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.spawnCharacter(.lion, on: anchor)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            self.playIdleAnimation(for: .utama)
            self.playIdleAnimation(for: .lion)
            self.onCharactersPlaced?()
        }
    }

    func spawnCharacter(_ character: Character, on anchor: AnchorEntity) {
        guard let entity = entity(for: character) else { return }

        if entity.parent == nil {
            anchor.addChild(entity)
        }

        let finalScale = targetScales[character] ?? entity.scale
        var finalTransform = entity.transform
        finalTransform.scale = finalScale

        entity.transform.scale = .zero
        playSpawnSFX()

        entity.move(
            to: finalTransform,
            relativeTo: entity.parent,
            duration: 1.0,
            timingFunction: .easeOut
        )
    }

    func playIdleAnimation(for character: Character) {
        guard animationStates[character] != .idle else { return }
        animationStates[character] = .idle
        playAnimation(for: character, namedLike: ["idle", "breath"])
    }

    func playTalkingAnimation(for character: Character) {
        guard animationStates[character] != .talking else { return }
        animationStates[character] = .talking
        playAnimation(for: character, namedLike: ["talk", "speak"])
    }

    func playRoarAnimation() {
        animationStates[.lion] = .roaring
        playAnimation(for: .lion, namedLike: ["roar"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.playIdleAnimation(for: .lion)
        }
    }

    func playGestureAnimation(for character: Character) {
        animationStates[character] = .gesturing
        playAnimation(for: character, namedLike: ["point", "gesture", "bow"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.playIdleAnimation(for: character)
        }
    }

    func transitionAnimation(from: CharacterAnimationState, to: CharacterAnimationState, duration: TimeInterval) {
        // TODO: Extend with explicit per-entity blend trees when production animation clips are available.
        for character in Character.allCases {
            if animationStates[character] != from { continue }

            switch to {
            case .idle:
                playIdleAnimation(for: character)
            case .talking:
                playTalkingAnimation(for: character)
            case .roaring:
                if character == .lion {
                    playRoarAnimation()
                }
            case .gesturing:
                playGestureAnimation(for: character)
            }

            if duration > 0 {
                // RealityKit transition duration is controlled in playAnimation call.
            }
        }
    }

    func faceCharactersTowardCamera(using arView: ARView, smooth: Bool) {
        guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        for character in Character.allCases {
            guard let entity = entity(for: character) else { continue }

            let position = entity.position(relativeTo: nil)
            let direction = cameraPosition - position
            let yaw = atan2f(direction.x, direction.z)
            let targetRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

            if smooth {
                let currentRotation = entity.orientation(relativeTo: nil)
                let blended = simd_slerp(currentRotation, targetRotation, 0.18)
                entity.setOrientation(blended, relativeTo: nil)
            } else {
                entity.setOrientation(targetRotation, relativeTo: nil)
            }
        }
    }

    private func playAnimation(for character: Character, namedLike keywords: [String]) {
        guard let entity = entity(for: character) else { return }

        if let matched = matchedAnimation(in: entity, keywords: keywords) {
            _ = entity.playAnimation(matched, transitionDuration: 0.3, startsPaused: false)
            return
        }

        if let fallback = entity.availableAnimations.first {
            _ = entity.playAnimation(fallback, transitionDuration: 0.3, startsPaused: false)
        }
    }

    private func matchedAnimation(in entity: ModelEntity, keywords: [String]) -> AnimationResource? {
        let normalizedKeywords = keywords.map { $0.lowercased() }

        return entity.availableAnimations.first { animation in
            let animationName = (animation.name ?? "").lowercased()
            return normalizedKeywords.contains(where: { animationName.contains($0) })
        }
    }

    private func entity(for character: Character) -> ModelEntity? {
        switch character {
        case .utama:
            return utamaEntity
        case .lion:
            return lionEntity
        }
    }

    private func scaleEntity(_ entity: ModelEntity, toApproximateHeight targetHeight: Float, for character: Character) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let measuredHeight = max(bounds.extents.y, 0.001)
        let scaleFactor = targetHeight / measuredHeight
        let scaleVector = SIMD3<Float>(repeating: scaleFactor)

        entity.scale = scaleVector
        targetScales[character] = scaleVector
    }

    private func loadModelEntity(named baseName: String, fallbackMesh: MeshResource, fallbackColor: UIColor) -> ModelEntity {
        if let loadedModel = try? ModelEntity.loadModel(named: "\(baseName).usdz") {
            return loadedModel
        }

        if let loadedModel = try? ModelEntity.loadModel(named: baseName) {
            return loadedModel
        }

        // TODO: Replace with production USDZ assets from Track F when available.
        let material = SimpleMaterial(color: fallbackColor, roughness: 0.35, isMetallic: false)
        return ModelEntity(mesh: fallbackMesh, materials: [material])
    }

    private func playSpawnSFX() {
        guard let url = Bundle.main.url(forResource: "spawn_shimmer", withExtension: "wav")
            ?? Bundle.main.url(forResource: "spawn_shimmer", withExtension: "wav", subdirectory: "Assets/Audio")
        else {
            return
        }

        do {
            spawnSFXPlayer = try AVAudioPlayer(contentsOf: url)
            spawnSFXPlayer?.prepareToPlay()
            spawnSFXPlayer?.play()
        } catch {
            // Missing optional SFX should not break spawn flow.
        }
    }
}
