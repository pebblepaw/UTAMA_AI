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
    private var utamaVariantPrototypes: [String: Entity] = [:]
    private var currentUtamaVariantKey: String = "idle"
    private var lionMotionWorkItem: DispatchWorkItem?

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

    private let utamaVariantFiles: [String: (subdirectory: String, fileName: String)] = [
        "idle": ("Assets/Models", "utama"),
        "talk": ("Assets/Animations", "utama_talking"),
        "gesture": ("Assets/Animations", "utama_gesture"),
        "bow": ("Assets/Animations", "utama_bow"),
        "dance": ("Assets/Animations", "utama_dance")
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

        if lionEntity == nil {
            lionEntity = loadCharacterEntity(
                named: "lion",
                fallbackMesh: .generateSphere(radius: 0.2),
                fallbackColor: .systemOrange
            )
            lionEntity?.name = "lion"
            print("[CharacterManager] lionEntity loaded, children: \(lionEntity?.children.count ?? 0)")
            preloadAnimations(for: .lion)
        }
    }

    /// Load animation resources from separate USDZ files into memory.
    private func preloadAnimations(for character: Character) {
        if character == .utama {
            preloadUtamaVariants()
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

        guard let utamaEntity, let lionEntity else { return }

        if utamaEntity.parent == nil {
            anchor.addChild(utamaEntity)
        }
        if lionEntity.parent == nil {
            anchor.addChild(lionEntity)
        }

        // Local anchor coordinates: Sultan at origin, lion offset to the right.
        utamaEntity.position = [0, 0, 0]
        lionEntity.position = [0.35, 0, 0.35]
        scaleEntity(utamaEntity, toApproximateHeight: 1.2, for: .utama)
        scaleEntity(lionEntity, toApproximateHeight: 0.55, for: .lion)
        applyGroundAlignment(to: utamaEntity, for: .utama)
        applyGroundAlignment(to: lionEntity, for: .lion)
        applyBaseOrientationOffsets()

        spawnCharacter(.utama, on: anchor)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.spawnCharacter(.lion, on: anchor)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.playGestureAnimation(for: .utama)
            self.playIdleAnimation(for: .lion)
            self.startLionAmbientMotionLoop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.playIdleAnimation(for: .utama)
                self.onCharactersPlaced?()
            }
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

    func playDanceAnimation(for character: Character) {
        animationStates[character] = .gesturing
        playAnimation(for: character, namedLike: ["dance", "run", "walk", "gesture"])

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
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

        let transitionDuration: TimeInterval = keywords.contains(where: {
            let lower = $0.lowercased()
            return lower.contains("talk") || lower.contains("speak")
        }) ? 0.65 : 0.35

        if character == .utama {
            let key = utamaVariantKey(for: keywords)
            switchUtamaVariant(to: key)
            return
        }

        // 1. Check pre-loaded extra animations from separate USDZ files
        if let extras = extraAnimations[character] {
            for keyword in keywords {
                if let animation = extras[keyword] {
                    _ = entity.playAnimation(animation, transitionDuration: transitionDuration, startsPaused: false)
                    return
                }
            }
        }

        // 2. Check animations embedded in the base model
        if let matched = matchedAnimation(in: entity, keywords: keywords) {
            _ = entity.playAnimation(matched, transitionDuration: transitionDuration, startsPaused: false)
            return
        }

        // 3. Fallback to first available animation
        if let fallback = entity.availableAnimations.first {
            _ = entity.playAnimation(fallback, transitionDuration: transitionDuration, startsPaused: false)
            return
        }

        // 4. Procedural fallback when no animation clips are available/match.
        playProceduralFallbackAnimation(on: entity, for: character, keywords: keywords)
    }

    private func preloadUtamaVariants() {
        for (key, descriptor) in utamaVariantFiles {
            guard
                let url = Bundle.main.url(
                    forResource: descriptor.fileName,
                    withExtension: "usdz",
                    subdirectory: descriptor.subdirectory
                ),
                let loaded = try? Entity.load(contentsOf: url)
            else {
                continue
            }
            utamaVariantPrototypes[key] = loaded
        }
    }

    private func utamaVariantKey(for keywords: [String]) -> String {
        let lower = keywords.joined(separator: ",").lowercased()
        if lower.contains("dance") {
            return "dance"
        }
        if lower.contains("bow") {
            return "bow"
        }
        if lower.contains("gesture") || lower.contains("point") {
            return "gesture"
        }
        if lower.contains("talk") || lower.contains("speak") {
            return "talk"
        }
        return "idle"
    }

    private func switchUtamaVariant(to key: String) {
        guard key != currentUtamaVariantKey else { return }
        guard
            let current = utamaEntity,
            let parent = current.parent,
            let prototype = utamaVariantPrototypes[key]
        else {
            return
        }

        let next = prototype.clone(recursive: true)
        next.name = "utama"
        next.transform = current.transform

        current.removeFromParent()
        parent.addChild(next)
        utamaEntity = next
        currentUtamaVariantKey = key

        if let animation = next.availableAnimations.first {
            _ = next.playAnimation(animation, transitionDuration: 0.15, startsPaused: false)
        }
    }

    private func startLionAmbientMotionLoop() {
        lionMotionWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.playAnimation(for: .lion, namedLike: self.randomLionMotionKeywords())
            self.startLionAmbientMotionLoop()
        }
        lionMotionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: workItem)
    }

    private func randomLionMotionKeywords() -> [String] {
        let options: [[String]] = [["walk"], ["run"], ["rest"], ["roar"]]
        return options.randomElement() ?? ["walk"]
    }

    private func matchedAnimation(in entity: Entity, keywords: [String]) -> AnimationResource? {
        let normalizedKeywords = keywords.map { $0.lowercased() }

        return entity.availableAnimations.first { animation in
            let animationName = (animation.name ?? "").lowercased()
            return normalizedKeywords.contains(where: { animationName.contains($0) })
        }
    }

    private func playProceduralFallbackAnimation(on entity: Entity, for character: Character, keywords: [String]) {
        let keywordString = keywords.joined(separator: ",")
        let lower = keywordString.lowercased()

        if lower.contains("talk") || lower.contains("speak") {
            // Gentle talking motion: tiny bob on Y.
            var up = entity.transform
            up.translation.y += 0.02
            entity.move(to: up, relativeTo: entity.parent, duration: 0.22, timingFunction: .easeInOut)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                var down = entity.transform
                down.translation.y -= 0.02
                entity.move(to: down, relativeTo: entity.parent, duration: 0.22, timingFunction: .easeInOut)
            }
            return
        }

        if lower.contains("gesture") || lower.contains("point") || lower.contains("bow") {
            var turn = entity.transform
            turn.rotation = turn.rotation * simd_quatf(angle: .pi / 18, axis: SIMD3<Float>(0, 1, 0))
            entity.move(to: turn, relativeTo: entity.parent, duration: 0.25, timingFunction: .easeInOut)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                var back = entity.transform
                back.rotation = back.rotation * simd_quatf(angle: -.pi / 18, axis: SIMD3<Float>(0, 1, 0))
                entity.move(to: back, relativeTo: entity.parent, duration: 0.25, timingFunction: .easeInOut)
            }
            return
        }

        if lower.contains("dance") || lower.contains("run") || lower.contains("walk") {
            var spin = entity.transform
            spin.rotation = spin.rotation * simd_quatf(angle: .pi / 8, axis: SIMD3<Float>(0, 1, 0))
            entity.move(to: spin, relativeTo: entity.parent, duration: 0.35, timingFunction: .easeInOut)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                var spinBack = entity.transform
                spinBack.rotation = spinBack.rotation * simd_quatf(angle: -.pi / 8, axis: SIMD3<Float>(0, 1, 0))
                entity.move(to: spinBack, relativeTo: entity.parent, duration: 0.35, timingFunction: .easeInOut)
            }
            return
        }

        if character == .lion || lower.contains("roar") {
            var lunge = entity.transform
            lunge.translation.z -= 0.08
            entity.move(to: lunge, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeInOut)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                var reset = entity.transform
                reset.translation.z += 0.08
                entity.move(to: reset, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeInOut)
            }
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
        let bounds = entity.visualBounds(relativeTo: entity)
        let minY = bounds.center.y - (bounds.extents.y * 0.5)
        // Force a stable baseline for Utama; rig bounds are inconsistent across exports.
        let verticalOffset: Float
        if character == .utama {
            verticalOffset = -0.12
        } else {
            let rawOffset = -minY - 0.03
            verticalOffset = min(max(rawOffset, -0.25), 0.25)
        }
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
