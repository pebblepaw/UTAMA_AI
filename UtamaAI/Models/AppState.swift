import Foundation

enum AppState: Equatable {
    case scanning
    case placing
    case conversing
    case vrTransition
    case vrPlaying
    case vrReturn
    case idle
}

enum Character: CaseIterable {
    case utama
    case lion
}

enum MicIndicatorState: Equatable {
    case idle
    case listening
    case aiSpeaking
}
