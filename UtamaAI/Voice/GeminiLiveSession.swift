import Foundation

protocol GeminiSessionDelegate: AnyObject {
    func sessionDidConnect()
    func sessionDidDisconnect(error: Error?)
    func didReceiveAudioChunk(_ pcmData: Data)
    func didReceiveTranscription(_ text: String, isUser: Bool)
    func didCompleteTurn()
}

final class GeminiLiveSession: NSObject {
    weak var delegate: GeminiSessionDelegate?

    private(set) var isConnected: Bool = false

    let apiKey: String

    private let urlSession: URLSession
    private let workQueue = DispatchQueue(label: "com.utama.voice.gemini.session")

    private var webSocket: URLSessionWebSocketTask?
    private var activePersona: CharacterPersona?
    private var retryCount = 0
    private var didDisconnectManually = false
    private var timeoutWorkItem: DispatchWorkItem?

    private let maxRetries = 3
    private let idleTimeoutSeconds: TimeInterval = 20

    init(apiKey: String) {
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config)

        super.init()
    }

    func connect(persona: CharacterPersona) {
        workQueue.async {
            self.activePersona = persona
            self.didDisconnectManually = false
            self.openSocket()
        }
    }

    func disconnect() {
        workQueue.async {
            self.didDisconnectManually = true
            self.retryCount = 0
            self.invalidateTimeoutWatcher()
            self.closeCurrentSocket(with: nil)
        }
    }

    func sendAudio(_ pcmData: Data) {
        let payload: [String: Any] = [
            "realtime_input": [
                "media_chunks": [[
                    "mime_type": "audio/pcm;rate=16000",
                    "data": pcmData.base64EncodedString()
                ]]
            ]
        ]

        send(jsonPayload: payload)
    }

    func sendText(_ text: String) {
        let payload: [String: Any] = [
            "client_content": [
                "turns": [[
                    "role": "user",
                    "parts": [["text": text]]
                ]],
                "turn_complete": true
            ]
        ]

        send(jsonPayload: payload)
    }

    private func openSocket() {
        guard !apiKey.isEmpty else {
            notifyDisconnect(error: GeminiLiveError.missingAPIKey)
            return
        }

        guard let persona = activePersona else {
            notifyDisconnect(error: GeminiLiveError.noPersonaConfigured)
            return
        }

        let endpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"

        guard let url = URL(string: endpoint) else {
            notifyDisconnect(error: GeminiLiveError.invalidURL)
            return
        }

        let task = urlSession.webSocketTask(with: url)
        webSocket = task
        task.resume()

        sendSetupMessage(persona: persona)
        startReceiveLoop()
        scheduleTimeoutWatcher()
    }

    private func closeCurrentSocket(with error: Error?) {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        if isConnected || error != nil {
            isConnected = false
            notifyDisconnect(error: error)
        }
    }

    private func sendSetupMessage(persona: CharacterPersona) {
        let payload: [String: Any] = [
            "setup": [
                "model": persona.modelId,
                "generation_config": [
                    "response_modalities": ["AUDIO"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": ["voice_name": persona.voiceName]
                        ]
                    ],
                    "output_audio_transcription": [:],
                    "input_audio_transcription": [:]
                ],
                "system_instruction": [
                    "parts": [["text": persona.systemPrompt]]
                ],
                "realtime_input_config": [
                    "automatic_activity_detection": [
                        "disabled": false,
                        "start_of_speech_sensitivity": "START_SENSITIVITY_HIGH",
                        "end_of_speech_sensitivity": "END_SENSITIVITY_LOW"
                    ]
                ]
            ]
        ]

        send(jsonPayload: payload)
    }

    private func send(jsonPayload: [String: Any]) {
        workQueue.async {
            guard let webSocket = self.webSocket else { return }

            do {
                let data = try JSONSerialization.data(withJSONObject: jsonPayload)
                webSocket.send(.data(data)) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.handleSocketFailure(error)
                    }
                }
            } catch {
                self.handleSocketFailure(error)
            }
        }
    }

    private func startReceiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            self.scheduleTimeoutWatcher()

            switch result {
            case .failure(let error):
                self.handleSocketFailure(error)
            case .success(let message):
                switch message {
                case .data(let data):
                    self.parseIncomingJSON(data: data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self.parseIncomingJSON(data: data)
                    }
                @unknown default:
                    break
                }

                self.startReceiveLoop()
            }
        }
    }

    private func parseIncomingJSON(data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let payload = object as? [String: Any]
        else {
            return
        }

        parsePayload(payload)
    }

    private func parsePayload(_ payload: [String: Any]) {
        if payload["setupComplete"] != nil {
            if !isConnected {
                isConnected = true
                retryCount = 0
                DispatchQueue.main.async {
                    self.delegate?.sessionDidConnect()
                }
            }
        }

        guard let serverContent = payload["serverContent"] as? [String: Any] else {
            return
        }

        if let modelTurn = serverContent["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {
            for part in parts {
                if
                    let inlineData = part["inlineData"] as? [String: Any],
                    let encodedAudio = inlineData["data"] as? String,
                    let audioData = Data(base64Encoded: encodedAudio)
                {
                    DispatchQueue.main.async {
                        self.delegate?.didReceiveAudioChunk(audioData)
                    }
                }

                if let text = part["text"] as? String {
                    DispatchQueue.main.async {
                        self.delegate?.didReceiveTranscription(text, isUser: false)
                    }
                }
            }
        }

        if let outputText = transcriptionText(from: serverContent["outputTranscription"]) {
            DispatchQueue.main.async {
                self.delegate?.didReceiveTranscription(outputText, isUser: false)
            }
        }

        if let inputText = transcriptionText(from: serverContent["inputTranscription"]) {
            DispatchQueue.main.async {
                self.delegate?.didReceiveTranscription(inputText, isUser: true)
            }
        }

        if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
            DispatchQueue.main.async {
                self.delegate?.didCompleteTurn()
            }
        }
    }

    private func transcriptionText(from rawValue: Any?) -> String? {
        if let string = rawValue as? String {
            return string
        }

        if
            let dictionary = rawValue as? [String: Any],
            let text = dictionary["text"] as? String
        {
            return text
        }

        return nil
    }

    private func handleSocketFailure(_ error: Error) {
        workQueue.async {
            self.invalidateTimeoutWatcher()

            guard !self.didDisconnectManually else {
                self.closeCurrentSocket(with: nil)
                return
            }

            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                self.closeCurrentSocket(with: nil)

                let retryDelay = TimeInterval(self.retryCount)
                self.workQueue.asyncAfter(deadline: .now() + retryDelay) {
                    self.openSocket()
                }
            } else {
                self.closeCurrentSocket(with: error)
            }
        }
    }

    private func scheduleTimeoutWatcher() {
        invalidateTimeoutWatcher()

        let timeoutItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.handleSocketFailure(GeminiLiveError.timeout)
        }

        timeoutWorkItem = timeoutItem
        workQueue.asyncAfter(deadline: .now() + idleTimeoutSeconds, execute: timeoutItem)
    }

    private func invalidateTimeoutWatcher() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private func notifyDisconnect(error: Error?) {
        DispatchQueue.main.async {
            self.delegate?.sessionDidDisconnect(error: error)
        }
    }
}

enum GeminiLiveError: LocalizedError {
    case missingAPIKey
    case noPersonaConfigured
    case invalidURL
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing."
        case .noPersonaConfigured:
            return "No character persona was configured before connecting."
        case .invalidURL:
            return "Invalid Gemini Live WebSocket URL."
        case .timeout:
            return "Gemini Live session timed out."
        }
    }
}
