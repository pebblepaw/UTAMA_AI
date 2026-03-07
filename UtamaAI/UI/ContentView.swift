import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var arSceneManager: ARSceneManager

    /// Tracks the fade-to-black overlay for VR transitions.
    @State private var vrFadeOpacity: Double = 0

    var body: some View {
        ZStack {
            // AR layer stays visible; VR cinematic is an overlay panel.
#if targetEnvironment(simulator)
            Color.black
                .ignoresSafeArea()
#else
            ARViewContainer(sceneManager: arSceneManager, appState: appCoordinator.appState)
                .ignoresSafeArea()
#endif

            // VR video layer
            if isVRActive {
                VRSceneView(vrPlayer: appCoordinator.vrScenePlayer)
                    .transition(.opacity)
            }

            // Fade-to-black overlay for transitions
            Color.black
                .ignoresSafeArea()
                .opacity(vrFadeOpacity)
                .allowsHitTesting(false)

            // UI overlays (hidden during VR)
            if !isVRActive {
                VStack(spacing: 12) {
                    if appCoordinator.appState == .scanning {
                        placementInstructionView
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
#if targetEnvironment(simulator)
                    Text("Simulator mode: AR camera feed is not available")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 4)
#endif

                    Spacer()

                    MicIndicatorView(
                        state: appCoordinator.micIndicatorState,
                        isConnected: appCoordinator.isGeminiConnected,
                        isMuted: appCoordinator.isMicMuted,
                        onTap: appCoordinator.toggleMicMute
                    )
                    .padding(.bottom, 28)
                }
                .padding(.top, 16)
            }

            // Error banner
            if let error = appCoordinator.lastErrorMessage {
                VStack {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appCoordinator.appState)
        .onChange(of: appCoordinator.appState) { _, newState in
            handleStateTransition(newState)
        }
    }

    private var isVRActive: Bool {
        switch appCoordinator.appState {
        case .vrPlaying:
            return true
        default:
            return false
        }
    }

    private func handleStateTransition(_ state: AppState) {
        switch state {
        case .vrTransition:
            // Fade to black
            withAnimation(.easeIn(duration: 1.0)) {
                vrFadeOpacity = 1.0
            }
            // After fade, coordinator moves to .vrPlaying
        case .vrPlaying:
            // Fade in from black to show video
            withAnimation(.easeOut(duration: 0.5)) {
                vrFadeOpacity = 0
            }
        case .vrReturn:
            // Fade to black before returning to AR
            withAnimation(.easeIn(duration: 0.5)) {
                vrFadeOpacity = 1.0
            }
        case .conversing:
            // Fade in from black to show AR again
            withAnimation(.easeOut(duration: 1.0)) {
                vrFadeOpacity = 0
            }
        default:
            vrFadeOpacity = 0
        }
    }

    private var placementInstructionView: some View {
        VStack(spacing: 8) {
            Text("Utama AI")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Point your camera at a flat surface")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(16)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(ARSceneManager())
}
