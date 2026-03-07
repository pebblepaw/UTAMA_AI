import AVFoundation
import Foundation

protocol AudioCaptureDelegate: AnyObject {
    func didCapturePCMData(_ data: Data)
}

final class AudioCaptureEngine {
    weak var delegate: AudioCaptureDelegate?

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.utama.voice.capture.processing")

    private let targetSampleRate: Double = 16_000
    private let chunkSamples = 1_600 // ~100ms

    private var converter: AVAudioConverter?
    private var pendingPCMData = Data()
    private var isCapturing = false

    private var targetFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: targetSampleRate, channels: 1, interleaved: true)!
    }

    init() {
        observeAudioInterruptions()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopCapture()
    }

    func startCapture() throws {
        guard !isCapturing else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        pendingPCMData.removeAll(keepingCapacity: true)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processingQueue.async {
                self?.handleCapturedBuffer(buffer)
            }
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stopCapture() {
        guard isCapturing else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
        pendingPCMData.removeAll(keepingCapacity: false)
    }

    @objc
    private func handleAudioInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else {
            return
        }

        switch type {
        case .began:
            stopCapture()
        case .ended:
            // TODO: Depending on product UX, restart only after explicit user confirmation.
            try? startCapture()
        @unknown default:
            break
        }
    }

    private func observeAudioInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func handleCapturedBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converted = convertToPCM16Mono16k(buffer: inputBuffer) else { return }

        pendingPCMData.append(converted)

        let chunkSizeBytes = chunkSamples * MemoryLayout<Int16>.size
        while pendingPCMData.count >= chunkSizeBytes {
            let chunk = pendingPCMData.prefix(chunkSizeBytes)
            pendingPCMData.removeFirst(chunkSizeBytes)
            delegate?.didCapturePCMData(Data(chunk))
        }
    }

    private func convertToPCM16Mono16k(buffer inputBuffer: AVAudioPCMBuffer) -> Data? {
        let format = inputBuffer.format

        if format.sampleRate == targetSampleRate,
           format.channelCount == 1,
           format.commonFormat == .pcmFormatInt16,
           let channelData = inputBuffer.int16ChannelData
        {
            let bytes = Int(inputBuffer.frameLength) * MemoryLayout<Int16>.size
            return Data(bytes: channelData.pointee, count: bytes)
        }

        guard let converter else { return nil }

        let ratio = targetSampleRate / format.sampleRate
        let expectedFrameCount = max(AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio), 1)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: expectedFrameCount) else {
            return nil
        }

        var providedInput = false
        var conversionError: NSError?

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            providedInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard conversionError == nil,
              status == .haveData || status == .inputRanDry,
              let outputChannel = outputBuffer.int16ChannelData
        else {
            return nil
        }

        let outputBytes = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: outputChannel.pointee, count: outputBytes)
    }
}
