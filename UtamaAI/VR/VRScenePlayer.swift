import AVFoundation
import Combine
import Foundation

final class VRScenePlayer: ObservableObject {
    // TODO: Implement Track D VR playback in the Agent 3 phase.
    @Published var isPlaying: Bool = false
    var onComplete: (() -> Void)?

    func preload() {
        // TODO: Track D01
    }

    func play() {
        isPlaying = true
        // TODO: Track D01
    }

    func stop() {
        isPlaying = false
        // TODO: Track D01
    }
}
