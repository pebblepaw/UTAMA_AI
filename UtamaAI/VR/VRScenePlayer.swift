import AVFoundation
import Combine
import Foundation

final class VRScenePlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    var onComplete: (() -> Void)?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var endObserver: NSObjectProtocol?

    /// Pre-load the video asset for instant playback on trigger.
    func preload() {
        guard let url = videoURL() else { return }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        playerItem = item
    }

    /// Start fullscreen playback.
    func play() {
        if player == nil || playerItem == nil {
            preload()
        }

        guard let player else { return }

        // Observe end-of-video
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnd()
        }

        player.seek(to: .zero)
        player.play()

        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }

    /// Stop playback and reset.
    func stop() {
        player?.pause()
        player?.seek(to: .zero)

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    /// The underlying AVPlayer for use in the SwiftUI video layer.
    var avPlayer: AVPlayer? { player }

    private func handlePlaybackEnd() {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.onComplete?()
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func videoURL() -> URL? {
        // Try bundle paths in order of likelihood
        if let url = Bundle.main.url(forResource: "lion_encounter_vr", withExtension: "mp4") {
            return url
        }
        if let url = Bundle.main.url(forResource: "lion_encounter_vr", withExtension: "mp4", subdirectory: "Assets/Video") {
            return url
        }
        return nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
