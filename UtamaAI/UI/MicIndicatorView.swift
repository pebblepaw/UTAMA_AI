import SwiftUI

struct MicIndicatorView: View {
    let state: MicIndicatorState
    let isConnected: Bool
    let isMuted: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(baseColor.opacity(0.25))
                    .frame(width: 86, height: 86)
                    .scaleEffect(state == .listening ? (pulse ? 1.08 : 0.9) : 1.0)
                    .animation(
                        state == .listening
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: pulse
                    )

                Circle()
                    .fill(baseColor)
                    .frame(width: 66, height: 66)

                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
        }
        .contentShape(Circle())
        .onTapGesture(perform: onTap)
        .onAppear {
            pulse = true
        }
    }

    private var baseColor: Color {
        if isMuted {
            return .gray
        }
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .aiSpeaking:
            return Color(red: 0.95, green: 0.74, blue: 0.2)
        }
    }

    private var iconName: String {
        if isMuted {
            return "mic.slash.fill"
        }
        switch state {
        case .idle, .listening:
            return "mic.fill"
        case .aiSpeaking:
            return "speaker.wave.2.fill"
        }
    }
}
