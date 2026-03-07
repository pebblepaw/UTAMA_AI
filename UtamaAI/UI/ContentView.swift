import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var arSceneManager: ARSceneManager

    var body: some View {
        ZStack {
#if targetEnvironment(simulator)
            Color.black
                .ignoresSafeArea()
                .opacity(appCoordinator.appState == .vrPlaying ? 0 : 1)
#else
            ARViewContainer(sceneManager: arSceneManager, appState: appCoordinator.appState)
                .ignoresSafeArea()
                .opacity(appCoordinator.appState == .vrPlaying ? 0 : 1)
#endif

            if appCoordinator.appState == .vrPlaying {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Text("VR scene is loading…")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                    )
            }

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

                if appCoordinator.appState == .conversing {
                    SubtitleView(text: appCoordinator.subtitleText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                MicIndicatorView(
                    state: appCoordinator.micIndicatorState,
                    isConnected: appCoordinator.isGeminiConnected
                )
                .padding(.bottom, 28)
            }
            .padding(.top, 16)
        }
        .animation(.easeInOut(duration: 0.3), value: appCoordinator.appState)
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
