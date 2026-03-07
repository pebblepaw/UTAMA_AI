import ARKit
import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var sceneManager: ARSceneManager
    let appState: AppState

    func makeUIView(context: Context) -> ARView {
        sceneManager.makeARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        sceneManager.updateForState(appState)
    }
}
