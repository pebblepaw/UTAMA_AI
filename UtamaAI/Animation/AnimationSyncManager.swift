import Foundation

private enum AnimationState {
    case idle
    case talking
    case roaring
}

final class AnimationSyncManager {
    weak var characterManager: CharacterManager?

    let talkingThreshold: Float = 0.05
    let idleThreshold: Float = 0.02

    var onLionRoarRequested: (() -> Void)?

    private let idleDebounceSeconds: TimeInterval = 0.2
    private var activeStates: [Character: AnimationState] = [:]
    private var idleDebounceWorkItems: [Character: DispatchWorkItem] = [:]

    func updateFromAmplitude(_ amplitude: Float, for character: Character) {
        if amplitude >= talkingThreshold {
            idleDebounceWorkItems[character]?.cancel()
            idleDebounceWorkItems[character] = nil

            if activeStates[character] != .talking {
                activeStates[character] = .talking
                characterManager?.playTalkingAnimation(for: character)
            }
            return
        }

        if amplitude <= idleThreshold {
            scheduleIdleTransition(for: character)
        }
    }

    func triggerLionRoar() {
        activeStates[.lion] = .roaring
        characterManager?.playRoarAnimation()
        onLionRoarRequested?()
    }

    private func scheduleIdleTransition(for character: Character) {
        idleDebounceWorkItems[character]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            self.activeStates[character] = .idle
            self.characterManager?.playIdleAnimation(for: character)
            self.idleDebounceWorkItems[character] = nil
        }

        idleDebounceWorkItems[character] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + idleDebounceSeconds, execute: workItem)
    }
}
