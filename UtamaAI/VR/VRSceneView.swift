import AVKit
import SwiftUI

/// Fullscreen video view for the VR cinematic scene.
/// Renders the AVPlayer from VRScenePlayer without transport controls.
struct VRSceneView: View {
    @ObservedObject var vrPlayer: VRScenePlayer

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = vrPlayer.avPlayer {
                VideoPlayer(player: player)
                    .disabled(true) // Prevent user interaction with video controls
                    .ignoresSafeArea()
            } else {
                // Fallback if video is missing
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
}
