import SwiftUI

@main
struct UtamaAIApp: App {
    @StateObject private var appCoordinator: AppCoordinator
    @StateObject private var arSceneManager: ARSceneManager

    init() {
        let coordinator = AppCoordinator()
        let sceneManager = ARSceneManager()

        coordinator.attachSceneManager(sceneManager)
        sceneManager.coordinator = coordinator

        _appCoordinator = StateObject(wrappedValue: coordinator)
        _arSceneManager = StateObject(wrappedValue: sceneManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
                .environmentObject(arSceneManager)
        }
    }
}
