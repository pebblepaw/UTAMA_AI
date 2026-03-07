import AVFoundation
import Combine
import Foundation

final class AppCoordinator: NSObject, ObservableObject {
    @Published var appState: AppState = .scanning
    @Published var isListening: Bool = false
    @Published var currentTranscript: String?
    @Published var subtitleText: String?
    @Published var micIndicatorState: MicIndicatorState = .idle
    @Published var isGeminiConnected: Bool = false
    @Published var lastErrorMessage: String?

    let animationSyncManager: AnimationSyncManager

    private let geminiSession: GeminiLiveSession
    private let audioCaptureEngine: AudioCaptureEngine
    private let audioStreamPlayer: AudioStreamPlayer

    private weak var arSceneManager: ARSceneManager?
    private var subtitleHideWorkItem: DispatchWorkItem?
    private var pendingInitialGreeting = true
    private var lionRoarPlayer: AVAudioPlayer?

    init(apiKey: String = CharacterPrompts.apiKey) {
        geminiSession = GeminiLiveSession(apiKey: apiKey)
        audioCaptureEngine = AudioCaptureEngine()
        audioStreamPlayer = AudioStreamPlayer()
        animationSyncManager = AnimationSyncManager()
        super.init()

        geminiSession.delegate = self
        audioCaptureEngine.delegate = self

        audioStreamPlayer.onAmplitudeUpdate = { [weak self] amplitude in
            self?.animationSyncManager.updateFromAmplitude(amplitude, for: .utama)
        }

        audioStreamPlayer.onPlaybackComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.micIndicatorState = .listening
                self?.isListening = true
                self?.scheduleSubtitleHideAfterTurn()
            }
        }

        animationSyncManager.onLionRoarRequested = { [weak self] in
            self?.playLionRoarSFX()
        }

        configureAudioSessionForVoice()
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
            self.audioStreamPlayer.stop()
            self.isListening = false
            self.micIndicatorState = .idle

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appState = .vrPlaying
            }
        }
    }

    func onVRComplete() {
        DispatchQueue.main.async {
            self.appState = .vrReturn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.appState = .conversing
                self.isListening = true
                self.micIndicatorState = .listening
                self.geminiSession.sendText("You just showed the traveler the vision of your lion encounter. Continue the conversation.")
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
            try audioCaptureEngine.startCapture()
            DispatchQueue.main.async {
                self.isListening = true
                self.micIndicatorState = .listening
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

    private func configureAudioSessionForVoice() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true)
        } catch {
            onError(error)
        }
    }

    private func handleModelText(_ text: String) {
        var cleanedText = text

        if cleanedText.contains("[LION_ROAR]") {
            cleanedText = cleanedText.replacingOccurrences(of: "[LION_ROAR]", with: "")
            animationSyncManager.triggerLionRoar()
        }

        if cleanedText.contains("[VR_SCENE]") {
            cleanedText = cleanedText.replacingOccurrences(of: "[VR_SCENE]", with: "")
            onVRTrigger()
        }

        DispatchQueue.main.async {
            self.subtitleHideWorkItem?.cancel()
            let trimmed = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.subtitleText = trimmed.isEmpty ? nil : trimmed
        }
    }

    private func scheduleSubtitleHideAfterTurn() {
        subtitleHideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.subtitleText = nil
        }
        subtitleHideWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func playLionRoarSFX() {
        guard let url = Bundle.main.url(
            forResource: "lion_roar",
            withExtension: "wav"
        ) ?? Bundle.main.url(
            forResource: "lion_roar",
            withExtension: "wav",
            subdirectory: "Assets/Audio"
        ) else {
            return
        }

        do {
            lionRoarPlayer = try AVAudioPlayer(contentsOf: url)
            lionRoarPlayer?.prepareToPlay()
            lionRoarPlayer?.play()
        } catch {
            onError(error)
        }
    }
}

extension AppCoordinator: GeminiSessionDelegate {
    func sessionDidConnect() {
        DispatchQueue.main.async {
            self.isGeminiConnected = true
            self.micIndicatorState = .listening

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

        if let error {
            onError(error)
        }
    }

    func didReceiveAudioChunk(_ pcmData: Data) {
        audioStreamPlayer.enqueueAudioChunk(pcmData)

        DispatchQueue.main.async {
            self.micIndicatorState = .aiSpeaking
            self.isListening = false
        }
    }

    func didReceiveTranscription(_ text: String, isUser: Bool) {
        DispatchQueue.main.async {
            self.currentTranscript = text
        }

        if isUser {
            return
        }

        handleModelText(text)
    }

    func didCompleteTurn() {
        DispatchQueue.main.async {
            self.isListening = true
            self.micIndicatorState = .listening
        }

        animationSyncManager.updateFromAmplitude(0, for: .utama)
    }
}

extension AppCoordinator: AudioCaptureDelegate {
    func didCapturePCMData(_ data: Data) {
        guard appState == .conversing, isListening else { return }
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
