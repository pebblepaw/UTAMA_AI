import AVFoundation
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
    @Published private(set) var utamaEntity: Entity?
    @Published private(set) var lionEntity: Entity?

    var onCharactersPlaced: (() -> Void)?

    private var animationStates: [Character: CharacterAnimationState] = [:]
    private var targetScales: [Character: SIMD3<Float>] = [:]
    private var baseOrientationOffsets: [Character: simd_quatf] = [:]
    private var spawnSFXPlayer: AVAudioPlayer?

    /// Pre-loaded animations keyed by character, then by keyword (e.g. "talk", "roar").
    private var extraAnimations: [Character: [String: AnimationResource]] = [
        .utama: [:],
        .lion: [:]
    ]

    /// Animation USDZ files to load per character (keyword → file name without extension).
    private let animationFiles: [Character: [String: String]] = [
        .utama: [
            "talk": "utama_talking",
            "gesture": "utama_gesture",
            "bow": "utama_bow",
            "dance": "utama_dance"
        ],
        .lion: [
            "roar": "lion_roar",
            "walk": "lion_walk",
            "run": "lion_run",
            "rest": "lion_resting"
        ]
    ]

    func loadCharacters() {
        if utamaEntity == nil {
            utamaEntity = loadCharacterEntity(
                named: "utama",
                fallbackMesh: .generateBox(size: 0.25),
                fallbackColor: .systemTeal
            )
            utamaEntity?.name = "utama"
            print("[CharacterManager] utamaEntity loaded, children: \(utamaEntity?.children.count ?? 0)")
            preloadAnimations(for: .utama)
        }
    }

    /// Load animation resources from separate USDZ files into memory.
    private func preloadAnimations(for character: Character) {
        // Utama animation USDZs have incompatible bind paths for this runtime rig.
        if character == .utama {
            return
        }
        guard let files = animationFiles[character] else { return }

        for (keyword, fileName) in files {
            // Try loading from Animations subdirectory first
            if let url = Bundle.main.url(forResource: fileName, withExtension: "usdz", subdirectory: "Assets/Animations"),
               let animEntity = try? Entity.load(contentsOf: url) {
                if let animation = animEntity.availableAnimations.first {
                    extraAnimations[character, default: [:]][keyword] = animation
                    continue
                }
            }

            // Fallback to direct name lookup
            if let animEntity = try? Entity.load(named: "\(fileName).usdz") {
                if let animation = animEntity.availableAnimations.first {
                    extraAnimations[character, default: [:]][keyword] = animation
                }
            } else if let animEntity = try? Entity.load(named: fileName) {
                if let animation = animEntity.availableAnimations.first {
                    extraAnimations[character, default: [:]][keyword] = animation
                }
            }
        }
    }

    func placeCharacters(on anchor: AnchorEntity) {
        loadCharacters()

        guard let utamaEntity else { return }

        if utamaEntity.parent == nil {
            anchor.addChild(utamaEntity)
        }

        utamaEntity.position = [0, 0, 0]
        scaleEntity(utamaEntity, toApproximateHeight: 1.1, for: .utama)
        applyGroundAlignment(to: utamaEntity, for: .utama)
        applyBaseOrientationOffsets()

        spawnCharacter(.utama, on: anchor)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.playIdleAnimation(for: .utama)
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

        if character == .utama {
            entity.transform = finalTransform
            playSpawnSFX()
            return
        }

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
            let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            let baseOffset = baseOrientationOffsets[character] ?? simd_quatf()
            let targetRotation = yawRotation * baseOffset

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

        // 1. Check pre-loaded extra animations from separate USDZ files
        // Avoid for Utama due to bind-point mismatch logs on device.
        if character != .utama, let extras = extraAnimations[character] {
            for keyword in keywords {
                if let animation = extras[keyword] {
                    _ = entity.playAnimation(animation, transitionDuration: 0.3, startsPaused: false)
                    return
                }
            }
        }

        // 2. Check animations embedded in the base model
        if let matched = matchedAnimation(in: entity, keywords: keywords) {
            _ = entity.playAnimation(matched, transitionDuration: 0.3, startsPaused: false)
            return
        }

        // 3. Fallback to first available animation
        if let fallback = entity.availableAnimations.first {
            _ = entity.playAnimation(fallback, transitionDuration: 0.3, startsPaused: false)
        }
    }

    private func matchedAnimation(in entity: Entity, keywords: [String]) -> AnimationResource? {
        let normalizedKeywords = keywords.map { $0.lowercased() }

        return entity.availableAnimations.first { animation in
            let animationName = (animation.name ?? "").lowercased()
            return normalizedKeywords.contains(where: { animationName.contains($0) })
        }
    }

    private func entity(for character: Character) -> Entity? {
        switch character {
        case .utama:
            return utamaEntity
        case .lion:
            return lionEntity
        }
    }

    private func scaleEntity(_ entity: Entity, toApproximateHeight targetHeight: Float, for character: Character) {
        let measuredHeight = max(maxVisualHeight(in: entity), 0.001)
        let rawScaleFactor = targetHeight / measuredHeight
        let scaleFactor = min(max(rawScaleFactor, 0.02), 8.0)
        let scaleVector = SIMD3<Float>(repeating: scaleFactor)

        entity.scale = scaleVector
        targetScales[character] = scaleVector
        print("[CharacterManager] \(character) scale measuredHeight=\(measuredHeight) scale=\(scaleFactor)")
    }

    private func applyGroundAlignment(to entity: Entity, for character: Character) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let minY = bounds.center.y - (bounds.extents.y * 0.5)
        // Nudge slightly downward so feet visually meet real ground.
        let verticalOffset = -minY - 0.08
        entity.position.y = verticalOffset
        print("[CharacterManager] \(character) bounds centerY=\(bounds.center.y) height=\(bounds.extents.y) minY=\(minY) yOffset=\(verticalOffset)")
    }

    private func centerEntityAtAnchor(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position.x -= bounds.center.x
        entity.position.z -= bounds.center.z
        print("[CharacterManager] centered entity x=\(entity.position.x) z=\(entity.position.z)")
    }

    private func loadCharacterEntity(named baseName: String, fallbackMesh: MeshResource, fallbackColor: UIColor) -> Entity {
        if baseName == "utama",
           let modelEntity = loadUtamaAsModelEntity()
        {
            return modelEntity
        }

        let subdirectories = ["Assets/Models", "Models", "Assets"]
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(forResource: baseName, withExtension: "usdz", subdirectory: subdirectory),
               let loaded = loadRenderableEntity(at: url, baseName: baseName, sourceLabel: subdirectory)
            {
                return loaded
            }
        }

        let bundleLookups = ["\(baseName).usdz", baseName]
        for lookup in bundleLookups {
            do {
                let entity = try Entity.load(named: lookup)
                if hasRenderableContent(entity) {
                    print("[CharacterManager] \(baseName) loaded by name (\(lookup))")
                    return entity
                }
                print("[CharacterManager] \(baseName) loaded by name but has no renderable content (\(lookup))")
            } catch {
                print("[CharacterManager] \(baseName) not found by name (\(lookup)): \(error)")
            }
        }

        print("[CharacterManager] ⚠️ Using fallback mesh for \(baseName)")
        let material = SimpleMaterial(color: fallbackColor, roughness: 0.35, isMetallic: false)
        return ModelEntity(mesh: fallbackMesh, materials: [material])
    }

    private func loadRenderableEntity(at url: URL, baseName: String, sourceLabel: String) -> Entity? {
        do {
            let entity = try Entity.load(contentsOf: url)
            if hasRenderableContent(entity) {
                print("[CharacterManager] \(baseName) loaded from \(sourceLabel) (\(entity.children.count) children)")
                return entity
            }
            print("[CharacterManager] \(baseName) loaded from \(sourceLabel) but has no renderable content")
        } catch {
            print("[CharacterManager] Failed to load \(baseName) from \(sourceLabel): \(error)")
        }

        do {
            let modelEntity = try ModelEntity.loadModel(contentsOf: url)
            print("[CharacterManager] \(baseName) fallback-loaded as ModelEntity from \(sourceLabel)")
            return modelEntity
        } catch {
            print("[CharacterManager] ModelEntity fallback failed for \(baseName) from \(sourceLabel): \(error)")
            return nil
        }
    }

    private func loadUtamaAsModelEntity() -> ModelEntity? {
        let candidates: [(subdirectory: String, file: String)] = [
            ("Assets/Models", "utama"),
            ("Models", "utama")
        ]

        for candidate in candidates {
            guard
                let url = Bundle.main.url(
                    forResource: candidate.file,
                    withExtension: "usdz",
                    subdirectory: candidate.subdirectory
                )
            else {
                continue
            }

            do {
                let model = try ModelEntity.loadModel(contentsOf: url)
                print("[CharacterManager] utama loaded as ModelEntity from \(candidate.subdirectory)/\(candidate.file).usdz")
                return model
            } catch {
                print("[CharacterManager] utama ModelEntity load failed from \(candidate.subdirectory)/\(candidate.file).usdz: \(error)")
            }
        }

        return nil
    }

    private func hasRenderableContent(_ entity: Entity) -> Bool {
        if entity.components[ModelComponent.self] != nil {
            return true
        }

        for child in entity.children where hasRenderableContent(child) {
            return true
        }
        return false
    }

    private func maxVisualHeight(in entity: Entity) -> Float {
        var maxHeight = entity.visualBounds(relativeTo: nil).extents.y
        for child in entity.children {
            maxHeight = max(maxHeight, maxVisualHeight(in: child))
        }
        return maxHeight
    }

    private func applyBaseOrientationOffsets() {
        // Utama USDZ uses a different local up-axis; correct pitch so he stands upright.
        baseOrientationOffsets[.utama] = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        baseOrientationOffsets[.lion] = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
    }

    private func playSpawnSFX() {
        guard let url = Bundle.main.url(forResource: "spawn_shimmer", withExtension: "wav", subdirectory: "Assets/Audio")
            ?? Bundle.main.url(forResource: "spawn_shimmer", withExtension: "wav")
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
