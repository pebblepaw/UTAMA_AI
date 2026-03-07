import AVFoundation
import Foundation

final class AudioStreamPlayer {
    var onAmplitudeUpdate: ((Float) -> Void)?
    var onPlaybackComplete: (() -> Void)?

    private(set) var currentAmplitude: Float = 0

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let processingQueue = DispatchQueue(label: "com.utama.voice.playback.processing")

    private let playbackFormat: AVAudioFormat
    private var scheduledBufferCount = 0

    var isPlaying: Bool {
        playerNode.isPlaying
    }

    init() {
        // AVAudioEngine mixers expect float formats; convert incoming Int16 PCM to float buffers.
        playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
        engine.prepare()

        do {
            try engine.start()
        } catch {
            // Keep object alive even if audio output fails; retries happen at enqueue-time.
        }
    }

    deinit {
        stop()
    }

    func enqueueAudioChunk(_ pcmData: Data) {
        processingQueue.async {
            guard let buffer = self.makePCMBuffer(from: pcmData) else { return }

            let amplitude = self.computeRMSAmplitude(from: pcmData)
            DispatchQueue.main.async {
                self.currentAmplitude = amplitude
                self.onAmplitudeUpdate?(amplitude)
            }

            self.scheduledBufferCount += 1

            self.playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }

                self.processingQueue.async {
                    self.scheduledBufferCount = max(self.scheduledBufferCount - 1, 0)

                    if self.scheduledBufferCount == 0 {
                        DispatchQueue.main.async {
                            self.currentAmplitude = 0
                            self.onAmplitudeUpdate?(0)
                            self.onPlaybackComplete?()
                        }
                    }
                }
            }

            if !self.playerNode.isPlaying {
                if !self.engine.isRunning {
                    try? self.engine.start()
                }
                self.playerNode.play()
            }
        }
    }

    func stop() {
        processingQueue.sync {
            playerNode.stop()
            playerNode.reset()
            scheduledBufferCount = 0
        }

        DispatchQueue.main.async {
            self.currentAmplitude = 0
            self.onAmplitudeUpdate?(0)
        }
    }

    private func makePCMBuffer(from pcmData: Data) -> AVAudioPCMBuffer? {
        let sampleCount = pcmData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        guard let destination = buffer.floatChannelData?.pointee else {
            return nil
        }

        pcmData.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            guard let source = samples.baseAddress else { return }
            for index in 0..<sampleCount {
                destination[index] = Float(source[index]) / Float(Int16.max)
            }
        }

        return buffer
    }

    private func computeRMSAmplitude(from pcmData: Data) -> Float {
        var sumSquares: Float = 0
        var sampleCount = 0

        pcmData.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            sampleCount = samples.count

            for sample in samples {
                let normalized = Float(sample) / Float(Int16.max)
                sumSquares += normalized * normalized
            }
        }

        guard sampleCount > 0 else { return 0 }
        return sqrtf(sumSquares / Float(sampleCount))
    }
}
