import AVFoundation
import Combine
import Foundation

final class AppCoordinator: NSObject, ObservableObject {
    @Published var appState: AppState = .scanning
    @Published var isListening: Bool = false
    @Published var isMicMuted: Bool = true
    @Published var micIndicatorState: MicIndicatorState = .idle
    @Published var isGeminiConnected: Bool = false
    @Published var lastErrorMessage: String?

    let animationSyncManager: AnimationSyncManager
    let vrScenePlayer: VRScenePlayer

    private let geminiSession: GeminiLiveSession
    private let audioCaptureEngine: AudioCaptureEngine
    private let audioStreamPlayer: AudioStreamPlayer

    private weak var arSceneManager: ARSceneManager?
    private var pendingInitialGreeting = true
    private var transitionWhooshPlayer: AVAudioPlayer?
    private var sentAudioChunkCount = 0
    private var completedTurnCount = 0

    init(apiKey: String = CharacterPrompts.apiKey) {
        geminiSession = GeminiLiveSession(apiKey: apiKey)
        audioCaptureEngine = AudioCaptureEngine()

        // Configure audio session BEFORE creating AudioStreamPlayer (which starts its AVAudioEngine)
        Self.configureInitialAudioSession()

        audioStreamPlayer = AudioStreamPlayer()
        animationSyncManager = AnimationSyncManager()
        vrScenePlayer = VRScenePlayer()
        super.init()

        print("[AppCoordinator] API key present: \(!geminiSession.apiKey.isEmpty), length: \(geminiSession.apiKey.count)")

        geminiSession.delegate = self
        audioCaptureEngine.delegate = self

        audioStreamPlayer.onAmplitudeUpdate = { [weak self] amplitude in
            self?.animationSyncManager.updateFromAmplitude(amplitude, for: .utama)
        }

        audioStreamPlayer.onPlaybackComplete = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isListening = !self.isMicMuted
                self.micIndicatorState = self.isMicMuted ? .idle : .listening
            }
        }

        vrScenePlayer.onComplete = { [weak self] in
            self?.onVRComplete()
        }

        // Pre-load VR video so it starts instantly
        vrScenePlayer.preload()
        // Audio session already configured via Self.configureInitialAudioSession() above
    }

    deinit {
        audioCaptureEngine.stopCapture()
        audioStreamPlayer.stop()
        geminiSession.disconnect()
    }

    func attachSceneManager(_ sceneManager: ARSceneManager) {
        arSceneManager = sceneManager
        animationSyncManager.characterManager = sceneManager.characterManager
    }

    func onPlaneDetected() {
        DispatchQueue.main.async {
            guard self.appState == .scanning else { return }
            self.appState = .placing
        }
    }

    func onCharactersPlaced() {
        DispatchQueue.main.async {
            guard self.appState == .placing || self.appState == .scanning else { return }
            self.appState = .conversing
            self.startConversation()
        }
    }

    func onVRTrigger() {
        DispatchQueue.main.async {
            guard self.appState == .conversing else { return }
            self.appState = .vrTransition

            // Stop audio pipeline during VR
            self.audioStreamPlayer.stop()
            self.audioCaptureEngine.stopCapture()
            self.isListening = false
            self.micIndicatorState = .idle

            // Play transition whoosh SFX
            self.playTransitionWhooshSFX()

            // After fade-to-black animation (1 second), start video
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appState = .vrPlaying
                self.vrScenePlayer.play()
            }
        }
    }

    func onVRComplete() {
        DispatchQueue.main.async {
            self.vrScenePlayer.stop()
            self.appState = .vrReturn

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appState = .conversing
                self.configureAudioSessionForVoice()

                do {
                    if !self.isMicMuted {
                        try self.audioCaptureEngine.startCapture()
                    }
                } catch {
                    self.onError(error)
                }

                self.isListening = !self.isMicMuted
                self.micIndicatorState = self.isMicMuted ? .idle : .listening

                // Send context to Gemini so it picks up naturally after the VR scene
                self.geminiSession.sendText(
                    "You just showed the traveler the vision of your lion encounter. Continue the conversation."
                )
            }
        }
    }

    func onError(_ error: Error) {
        DispatchQueue.main.async {
            self.lastErrorMessage = error.localizedDescription
            self.micIndicatorState = .idle
        }
    }

    func startConversation() {
        guard !geminiSession.apiKey.isEmpty else {
            onError(AppCoordinatorError.missingAPIKey)
            return
        }

        configureAudioSessionForVoice()
        pendingInitialGreeting = true

        geminiSession.connect(persona: CharacterPrompts.sangNilaUtama)

        do {
            if !isMicMuted {
                try audioCaptureEngine.startCapture()
            }
            DispatchQueue.main.async {
                self.isListening = !self.isMicMuted
                self.micIndicatorState = self.isMicMuted ? .idle : .listening
            }
        } catch {
            onError(error)
        }
    }

    func stopConversation() {
        audioCaptureEngine.stopCapture()
        audioStreamPlayer.stop()
        geminiSession.disconnect()

        DispatchQueue.main.async {
            self.isListening = false
            self.micIndicatorState = .idle
        }
    }

    func toggleMicMute() {
        DispatchQueue.main.async {
            self.isMicMuted.toggle()
            self.isListening = !self.isMicMuted
            self.micIndicatorState = self.isMicMuted ? .idle : .listening

            guard self.appState == .conversing else { return }

            do {
                if self.isMicMuted {
                    self.audioCaptureEngine.stopCapture()
                } else {
                    try self.audioCaptureEngine.startCapture()
                }
            } catch {
                self.onError(error)
            }
        }
    }

    private func configureAudioSessionForVoice() {
        Self.configureInitialAudioSession()
    }

    private static func configureInitialAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true)
        } catch {
            print("[AppCoordinator] \u{26a0}\u{fe0f} Audio session config failed: \(error)")
        }
    }

    private func handleModelText(_ text: String) {
        var cleanedText = text

        if cleanedText.contains("[LION_ROAR]") {
            cleanedText = cleanedText.replacingOccurrences(of: "[LION_ROAR]", with: "")
            animationSyncManager.triggerLionRoar()
        }

        if cleanedText.contains("[DANCE]") {
            cleanedText = cleanedText.replacingOccurrences(of: "[DANCE]", with: "")
            animationSyncManager.triggerUtamaDance()
        } else if cleanedText.contains("[GESTURE]") || cleanedText.contains("[POINT]") {
            cleanedText = cleanedText
                .replacingOccurrences(of: "[GESTURE]", with: "")
                .replacingOccurrences(of: "[POINT]", with: "")
            animationSyncManager.triggerUtamaGesture()
        }

        if cleanedText.contains("[VR_SCENE]") {
            cleanedText = cleanedText.replacingOccurrences(of: "[VR_SCENE]", with: "")
            onVRTrigger()
        }
    }

    private func playTransitionWhooshSFX() {
        guard let url = Bundle.main.url(
            forResource: "transition_whoosh",
            withExtension: "wav",
            subdirectory: "Assets/Audio"
        ) ?? Bundle.main.url(
            forResource: "transition_whoosh",
            withExtension: "wav"
        ) else {
            return
        }

        do {
            transitionWhooshPlayer = try AVAudioPlayer(contentsOf: url)
            transitionWhooshPlayer?.prepareToPlay()
            transitionWhooshPlayer?.play()
        } catch {
            // Non-critical — transition continues without SFX
        }
    }
}

extension AppCoordinator: GeminiSessionDelegate {
    func sessionDidConnect() {
        DispatchQueue.main.async {
            self.isGeminiConnected = true
            self.micIndicatorState = self.isMicMuted ? .idle : .listening

            if self.pendingInitialGreeting {
                self.pendingInitialGreeting = false
                self.geminiSession.sendText("A new traveler has arrived. Greet them.")
            }
        }
    }

    func sessionDidDisconnect(error: Error?) {
        DispatchQueue.main.async {
            self.isGeminiConnected = false
            self.isListening = false
            self.micIndicatorState = .idle
        }
        audioStreamPlayer.stop()

        if let error {
            onError(error)
        }
    }

    func didReceiveAudioChunk(_ pcmData: Data) {
        guard appState == .conversing else { return }
        audioStreamPlayer.enqueueAudioChunk(pcmData)

        DispatchQueue.main.async {
            self.micIndicatorState = .aiSpeaking
            // Keep mic capture active to support interruption/barge-in.
            self.isListening = true
        }
    }

    func didReceiveTranscription(_ text: String, isUser: Bool) {
        guard appState == .conversing else { return }
        if isUser {
            let normalized = text.lowercased()
            if normalized.contains("show me") || normalized.contains("show what happened")
                || normalized.contains("take me back") || normalized.contains("show the scene")
            {
                onVRTrigger()
            }
            return
        }

        handleModelText(text)
    }

    func didCompleteTurn() {
        guard appState == .conversing else { return }
        completedTurnCount += 1
        if completedTurnCount % 3 == 0 {
            animationSyncManager.triggerUtamaDance()
        } else {
            animationSyncManager.triggerUtamaGesture()
        }

        DispatchQueue.main.async {
            self.isListening = !self.isMicMuted
            self.micIndicatorState = self.isMicMuted ? .idle : .listening
        }

        animationSyncManager.updateFromAmplitude(0, for: .utama)
    }
}

extension AppCoordinator: AudioCaptureDelegate {
    func didCapturePCMData(_ data: Data) {
        guard appState == .conversing, !isMicMuted, isGeminiConnected else { return }
        sentAudioChunkCount += 1
        if sentAudioChunkCount % 20 == 0 {
            print("[AppCoordinator] sent mic audio chunks: \(sentAudioChunkCount)")
        }
        geminiSession.sendAudio(data)
    }
}

enum AppCoordinatorError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GOOGLE_API_KEY is missing. Set it in the environment before launching the app."
        }
    }
}
