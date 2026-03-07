# Utama AI - Engineering Handoff

Date: 7 March 2026  
Authoring context: Track A + B + C execution pass completed first; Agent 3 scope intentionally deferred.

## 1) Current State Summary

- Repository now contains a working iOS app scaffold at `UtamaAI/` plus `UtamaAI.xcodeproj`.
- Track A (foundation), Track B (voice integration), and Track C (animation sync/effects) are implemented at code level.
- Simulator build is passing with Xcode 15.4.
- Physical iPhone deployment is currently blocked by Xcode/device OS mismatch.

## 2) What Was Implemented

### A) iOS Foundation (Track A)

- `UtamaAI/App/UtamaAIApp.swift` - app entry wiring for coordinator + AR scene manager.
- `UtamaAI/App/AppCoordinator.swift` - app state machine and voice pipeline orchestration.
- `UtamaAI/Models/AppState.swift` - `AppState`, `Character`, and mic indicator enums.
- `UtamaAI/AR/ARSceneManager.swift` - AR session, plane detection, coaching overlay, placement logic.
- `UtamaAI/AR/ARViewContainer.swift` - SwiftUI wrapper for ARView.
- `UtamaAI/AR/CharacterManager.swift` - character loading, placement, animation controls, spawn effect.
- `UtamaAI/UI/ContentView.swift` - state-driven main UI composition.
- `UtamaAI/UI/SubtitleView.swift`, `UtamaAI/UI/MicIndicatorView.swift` - overlays.
- `UtamaAI/Info.plist` - camera/mic usage descriptions and iPhone orientation config.

### B) Voice/AI (Track B)

- `UtamaAI/Voice/GeminiLiveSession.swift` - websocket setup, JSON protocol parsing, retries/timeouts.
- `UtamaAI/Voice/AudioCaptureEngine.swift` - microphone capture + 16kHz mono PCM conversion.
- `UtamaAI/Voice/AudioStreamPlayer.swift` - streamed playback + amplitude callbacks.
- `UtamaAI/Config/CharacterPrompts.swift` - persona prompt and API key accessor.

### C) Animation/VFX (Track C)

- `UtamaAI/Animation/AnimationSyncManager.swift` - amplitude threshold/debounce state transitions.
- `UtamaAI/AR/CharacterManager.swift` - spawn effect + camera-facing updates.

### Project/Assets Scaffold

- `UtamaAI.xcodeproj/project.pbxproj` generated and wired to source/resource files.
- `UtamaAI/Assets/Models/.gitkeep`
- `UtamaAI/Assets/Animations/.gitkeep`
- `UtamaAI/Assets/Audio/.gitkeep`
- `UtamaAI/Assets/Video/.gitkeep`
- `UtamaAI/Assets.xcassets/Contents.json`

## 3) Important Runtime Fixes Already Applied

- Fixed startup crash (`libc++abi ... uncaught exception of type NSException`) caused by incompatible `AVAudioEngine` connection format in `AudioStreamPlayer`.
  - Player now uses mixer-compatible float playback format and converts incoming Int16 PCM.
- Fixed Swift compile errors in:
  - `AudioCaptureEngine` (`.noDataNow` enum case)
  - `GeminiLiveSession` (explicit `self` capture in closure)
  - `CharacterManager` (optional animation name handling)

## 4) Validation Done

### Build (passes)

```bash
xcodebuild \
  -project /Users/prittamravi/UTAMA_AI/UtamaAI.xcodeproj \
  -scheme UtamaAI \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: `BUILD SUCCEEDED`

### Simulator launch (passes)

- App installs and launches via `simctl`.
- In simulator, AR camera feed is not available; `ContentView` includes a simulator-mode fallback message.

## 5) Known Blockers

### Physical device deployment blocker

- Connected device: iOS `26.1`.
- Current Xcode: `15.4`.
- Error: `kAMDMobileImageMounterPersonalizedBundleMissingVariantError`
- Meaning: installed Xcode does not include compatible developer disk image for the device OS.

### Mandatory compatibility gate (new engineer must run first)

Before any device deployment attempt, run:

```bash
xcodebuild -version
xcodebuild -showsdks | rg "iOS"
```

Then in Xcode:

1. Open `Window -> Devices and Simulators`
2. Select the connected iPhone
3. Note the iOS version shown for the device

Pass criteria:

- Xcode can prepare/mount developer image for that exact device OS version.
- Device appears as an available run destination (not "unpaired"/"unsupported"/"missing variant").

Fail criteria:

- Any image-mount/personalization error such as  
  `kAMDMobileImageMounterPersonalizedBundleMissingVariantError`
- Or device remains unavailable for run destination.

If fail:

- Install newer compatible Xcode and re-run the gate above before continuing.

### Required unblock action

1. Install an Xcode version that supports iOS 26.1 (likely newer/beta channel as needed).
2. Switch active developer directory:

```bash
sudo xcode-select -s /Applications/<NewXcodeApp>.app/Contents/Developer
xcodebuild -version
```

3. Re-open Xcode, reconnect iPhone, enable Developer Mode, trust/pair device.

## 6) What Is Intentionally Deferred (per request)

- Agent 3 track is deferred:
  - Track D (VR player + transitions)
  - Track E (final UI polish overlays)
  - Track F (asset sourcing/conversion)
- Track G integration tests are pending until D/E/F are ready.

## 7) Next Engineer Priority Order

1. **Unblock physical iPhone run**
   - Update Xcode to version compatible with iOS 26.1.
   - Pair device in `Xcode -> Window -> Devices and Simulators`.
2. **Run A+B+C on real device**
   - Verify camera permission flow, mic permission flow.
   - Verify state transitions (`scanning -> placing -> conversing`).
   - Verify Gemini voice roundtrip with real `GOOGLE_API_KEY`.
3. **Stabilize runtime behaviors**
   - Check latency, interruptions, reconnect edge cases.
   - Confirm `[LION_ROAR]` marker behavior.
4. **Proceed to deferred scope**
   - Implement Track D/E/F.
   - Then run Track G integration/performance/demo rehearsal.

## 8) Environment Notes

- API key expected via environment variable:

```bash
GOOGLE_API_KEY=<key>
```

- App reads this in `CharacterPrompts.apiKey`.
- If missing, conversation start is intentionally blocked with explicit error.

## 9) Suggested First Command Set For New Engineer

```bash
cd /Users/prittamravi/UTAMA_AI
git status --short
xcodebuild -version
xcodebuild -list -project /Users/prittamravi/UTAMA_AI/UtamaAI.xcodeproj
xcodebuild -showsdks | rg "iOS"
```

Then confirm device OS in `Window -> Devices and Simulators` and only proceed if compatibility gate passes.
