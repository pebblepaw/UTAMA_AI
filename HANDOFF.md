# Utama AI — Engineering Handoff (Bug Fix Pass)

Date: 7 March 2026 (Evening)  
Context: App builds and installs on device. Three runtime bugs prevent demo from working.  
Priority: **Fix these 3 bugs. Everything else is done.**

---

## 1) Situation

The app compiles with **zero warnings** and installs on the target iPhone ("Pebble", iOS 26.2).  
All assets (3D models, animations, audio SFX, VR video) are bundled and present.  
All code tracks (A through F) are implemented.

**However, on-device runtime testing reveals 3 critical bugs:**

| # | Bug | Severity | File |
|---|-----|----------|------|
| BUG-1 | Sultan (Utama) character is **invisible** — only the Lion appears | Critical | `CharacterManager.swift` |
| BUG-2 | Lion is **oriented head-down** (nose pointing at floor, ~90° wrong on X) | Critical | `CharacterManager.swift` |
| BUG-3 | **"Gemini Live session timed out"** — WebSocket never connects | Critical | `GeminiLiveSession.swift` |

Audio SFX also don't play during the session, but that's likely downstream of BUG-3 (no conversation = no triggers).

---

## 2) Bug Details & Root Cause Analysis

### BUG-1: Sultan Model Invisible

**Symptom:** On device, only the Lion character renders. Sultan (Utama) is nowhere visible. No crash, no error log about loading failure.

**What was tried:**  
- Changed `ModelEntity.loadModel()` → `Entity.load(contentsOf:)` to handle scene graph hierarchies  
- Added debug print statements (`[CharacterManager] utama loaded from Assets/Models/`)  
- Both models are confirmed present in the built app bundle (verified via `ls` on build output)

**Likely root causes (investigate in order):**
1. **`Entity.load(contentsOf:)` may succeed but return an entity with zero visual children.** The Sultan USDZ (exported from Blender via Mixamo rigging) has a complex scene graph: Armature → skeleton → mesh. RealityKit may load the container entity but the mesh child may not be a direct `ModelEntity`. Check `entity.children` recursively.
2. **Bundle subdirectory path issue on device.** The code uses `Bundle.main.url(forResource: "utama", withExtension: "usdz", subdirectory: "Assets/Models")`. On device, the `Assets/` folder is a **folder reference** in the Xcode project (not individual file refs). Verify the subdirectory path resolves correctly on device vs simulator. Try alternative paths like just `"Models"` or no subdirectory.
3. **Scale issue.** The `scaleEntity()` method divides by `visualBounds.extents.y`. If the loaded Entity's bounds are computed differently than expected (e.g., if the entity has no visual bounds because the mesh is in a child), scale could be 0 or enormous.

**Key code location:** `CharacterManager.swift` lines ~282-318 (`loadCharacterEntity` method) and lines ~94-120 (`placeCharacters` method).

**Debug approach:**
```swift
// Add these prints after loading utama entity:
print("[DEBUG] utama entity: \(utamaEntity)")
print("[DEBUG] utama children: \(utamaEntity?.children.count)")
print("[DEBUG] utama bounds: \(utamaEntity?.visualBounds(relativeTo: nil))")
print("[DEBUG] utama scale: \(utamaEntity?.scale)")

// Walk the entity tree:
func printEntityTree(_ entity: Entity, indent: String = "") {
    print("\(indent)\(entity.name) [\(type(of: entity))] children=\(entity.children.count)")
    for child in entity.children {
        printEntityTree(child, indent: indent + "  ")
    }
}
printEntityTree(utamaEntity!)
```

### BUG-2: Lion Oriented Head-Down

**Symptom:** Lion model appears on device but is rotated roughly -90° on the X-axis (nose pointing straight into the ground, belly facing the camera).

**What was tried:**  
- Switched from `ModelEntity.loadModel()` → `Entity.load(contentsOf:)` to preserve root transforms
- This was expected to fix the Y-up/Z-up axis conversion, but it didn't fully resolve it

**Likely root causes:**
1. **Blender export axis mismatch.** The Lion USDZ was exported from Blender 5.0.1. Blender uses Z-up; USD uses Y-up. The Blender USD exporter applies a root transform to convert, but RealityKit's `Entity.load()` may or may not respect it consistently. The Lion FBX from CGTrader was originally Z-up (common for game assets).
2. **The USDZ itself may have the wrong rest orientation.** Quick Look (macOS) may display it correctly because it applies its own transform, while RealityKit loads it raw.

**Fix approaches (try in order):**
1. **Apply a corrective rotation after loading:**
   ```swift
   // In CharacterManager, after loading the lion entity:
   lionEntity?.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0)) 
   // Rotates -90° around X-axis (if head is pointing down into floor)
   // Try positive .pi/2 if negative makes it worse
   ```
2. **Re-export the Lion USDZ from Blender** with explicit axis settings:
   - In Blender: File → Export → USD. Check "Convert Orientation" and set Up=Y, Forward=-Z.
   - The source FBX files are in `LIONASSETS/uploads_files_6678807_Lion@Bite/`
   - The conversion scripts are in `Scripts/convert_lion_to_usdz.py`
3. **Check if the issue is in scaling code.** `scaleEntity()` uses `visualBounds.extents.y` — if the lion's bounding box is measured before rotation correction, the Y extent could be wrong (measuring depth instead of height), causing incorrect scaling.

**Key code location:** `CharacterManager.swift` lines ~94-120 (`placeCharacters`) and ~271-279 (`scaleEntity`).

### BUG-3: Gemini WebSocket Timeout

**Symptom:** Console shows "Gemini Live session timed out" error. No voice conversation occurs.

**What was tried:**  
- Added `URLSessionWebSocketDelegate` so setup message sends only after `didOpenWithProtocol` fires
- Set `config.waitsForConnectivity = true` on URLSession
- API key is hardcoded as fallback in `CharacterPrompts.apiKey` (value: `AIzaSyDPB69YM6z94RjzWrtiMb_-fwcNVWtgHSM`)

**Console error context from device run:**
```
nw_flow_add_write_request [C1 74.125.130.95:443 failed parent-flow ...] cannot accept write requests
nw_write_request_report [C1] Send failed with error "Socket is not connected"
```
This appeared across connections C1-C4, suggesting repeated retry attempts all failing.

**Likely root causes (investigate in order):**
1. **`URLSessionWebSocketDelegate` may not be firing.** The `GeminiLiveSession` class extends `NSObject` and conforms to `URLSessionWebSocketDelegate`. But the URLSession must be created with `delegate: self` — verify this is set. Current code creates the session in `init()`:
   ```swift
   urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
   ```
   Check that `self` is fully initialized when this runs (it's called after `super.init()`). If the delegate isn't set properly, `didOpenWithProtocol` never fires, setup message never sends, and the 20-second timeout triggers.
   
2. **Network connectivity on device.** The error shows `interface: pdp_ip0[lte]` — the phone was on cellular. The WebSocket endpoint is `wss://generativelanguage.googleapis.com/...`. Possible that:
   - Cellular network blocks WebSocket upgrades
   - DNS resolution fails on cellular
   - **Try WiFi instead of cellular.**

3. **API key may be invalid or expired.** The hardcoded key is `AIzaSyDPB69YM6z94RjzWrtiMb_-fwcNVWtgHSM`. Verify it works by testing in a browser or curl:
   ```bash
   curl "https://generativelanguage.googleapis.com/v1beta/models?key=AIzaSyDPB69YM6z94RjzWrtiMb_-fwcNVWtgHSM"
   ```
   If this returns a 403 or error, the key is the problem.

4. **The setup message JSON may be malformed or the model ID may be wrong.** Current model: `models/gemini-2.5-flash-native-audio-preview-12-2025`. Check if this model is still available. The setup payload includes `output_audio_transcription` and `input_audio_transcription` fields — verify they're in the right location in the JSON structure (they should be nested under `generation_config`, not under `setup` directly).

**Key code location:** `GeminiLiveSession.swift` lines ~30-40 (init), ~83-107 (openSocket), ~120-155 (sendSetupMessage), ~320-360 (URLSessionWebSocketDelegate extension).

**Debug approach:**
```swift
// Add to openSocket():
print("[GeminiLive] Opening socket to: \(endpoint)")
print("[GeminiLive] API key length: \(apiKey.count), prefix: \(String(apiKey.prefix(10)))")

// Add to URLSessionWebSocketDelegate:
func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                didOpenWithProtocol protocol: String?) {
    print("[GeminiLive] ✅ WebSocket DID OPEN")  // If this never prints, delegate isn't wired
    ...
}

// Add to urlSession(_:task:didCompleteWithError:):
print("[GeminiLive] ❌ Task completed with error: \(error)")
```

---

## 3) Current File Inventory

### Source Files (16 Swift files, all compiling)

| File | Lines | Purpose | Modified This Session |
|------|-------|---------|-----------------------|
| `UtamaAI/App/UtamaAIApp.swift` | ~30 | App entry, wires coordinator + scene manager | No |
| `UtamaAI/App/AppCoordinator.swift` | 348 | State machine, voice pipeline, VR orchestration | **Yes** — added VR flow, audio session fix, API key fix |
| `UtamaAI/Models/AppState.swift` | ~30 | AppState, Character, MicIndicatorState enums | No |
| `UtamaAI/AR/ARSceneManager.swift` | 166 | AR session, plane detection, coaching, placement | Minor — fixed deprecation |
| `UtamaAI/AR/ARViewContainer.swift` | ~30 | UIViewRepresentable wrapper | No |
| `UtamaAI/AR/CharacterManager.swift` | 335 | **KEY FILE** — Entity loading, animations, spawn | **Yes** — Entity.load(), multi-anim |
| `UtamaAI/Animation/AnimationSyncManager.swift` | ~65 | Amplitude → animation state transitions | No |
| `UtamaAI/Voice/GeminiLiveSession.swift` | 380 | **KEY FILE** — WebSocket client, Gemini protocol | **Yes** — URLSessionWebSocketDelegate |
| `UtamaAI/Voice/AudioCaptureEngine.swift` | 157 | Mic capture, PCM conversion | Minor — fixed deprecation |
| `UtamaAI/Voice/AudioStreamPlayer.swift` | 136 | PCM playback, amplitude calculation | No |
| `UtamaAI/Config/CharacterPrompts.swift` | 82 | Persona, system prompt, API key | **Yes** — hardcoded API key fallback |
| `UtamaAI/UI/ContentView.swift` | 144 | Main view: AR + VR layers + transitions | **Yes** — added VR view, fade overlay |
| `UtamaAI/UI/SubtitleView.swift` | ~50 | Subtitle text overlay | No |
| `UtamaAI/UI/MicIndicatorView.swift` | ~80 | Mic state indicator | No |
| `UtamaAI/VR/VRScenePlayer.swift` | 98 | AVPlayer video playback | **Yes** — full implementation |
| `UtamaAI/VR/VRSceneView.swift` | 33 | SwiftUI VideoPlayer wrapper | **Yes** — new file |

### Asset Files (all present in bundle)

| Directory | Files | Total Size |
|-----------|-------|------------|
| `Assets/Models/` | `utama.usdz` (29MB), `lion.usdz` (14MB) | 43MB |
| `Assets/Animations/` | 8 USDZ files (4 utama + 4 lion) | ~172MB |
| `Assets/Audio/` | `lion_roar.wav`, `ambient_shore.wav`, `spawn_shimmer.wav`, `transition_whoosh.wav` | ~64MB |
| `Assets/Video/` | `lion_encounter_vr.mp4` (1920×1080, H.264, 14.6s) | 35MB |

**Note:** `Assets/` is registered as a **folder reference** in the Xcode project (not individual file refs). All files placed in this directory tree are automatically copied into the app bundle. No pbxproj edits needed for new assets.

### Project Configuration

| Property | Value |
|----------|-------|
| Xcode | 26.3 (Build 17C529) |
| iOS SDK | 26.2 |
| Deployment Target | iOS 17.0 |
| Bundle ID | `com.utama.ai` |
| Development Team | `6NJ4R8FA37` |
| Signing | Automatic |
| Gemini Model | `models/gemini-2.5-flash-native-audio-preview-12-2025` |
| Gemini Voice | `Charon` |
| API Key | Hardcoded fallback in `CharacterPrompts.swift` |
| Target Device | iPhone "Pebble" (iOS 26.2) |

---

## 4) Architecture Quick Reference

```
App Launch
  → UtamaAIApp creates AppCoordinator + ARSceneManager
  → AppCoordinator creates GeminiLiveSession, AudioCaptureEngine, AudioStreamPlayer, VRScenePlayer
  → ARSceneManager creates CharacterManager

State Machine: .scanning → .placing → .conversing → .vrTransition → .vrPlaying → .vrReturn → .conversing

Voice Pipeline:
  iPhone Mic → AudioCaptureEngine (16kHz PCM) → GeminiLiveSession (WebSocket) → Gemini API
  Gemini API → GeminiLiveSession → AudioStreamPlayer (24kHz PCM) → iPhone Speaker
  AudioStreamPlayer.amplitude → AnimationSyncManager → CharacterManager.playTalkingAnimation()

VR Trigger:
  Gemini transcription contains "[VR_SCENE]" → AppCoordinator.onVRTrigger()
  → stops audio pipeline → fade to black → play lion_encounter_vr.mp4 → fade back → resume

Lion Roar Trigger:
  Gemini transcription contains "[LION_ROAR]" → AnimationSyncManager.triggerLionRoar()
  → CharacterManager.playRoarAnimation() + play lion_roar.wav
```

---

## 5) How to Build & Run

```bash
# Simulator (zero warnings):
xcodebuild -project UtamaAI.xcodeproj -scheme UtamaAI -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  CODE_SIGNING_ALLOWED=NO build

# Device (requires signing — Apple account already configured):
# Use Xcode UI: select "Pebble" device → Cmd+R
# Or:
xcodebuild -project UtamaAI.xcodeproj -scheme UtamaAI -configuration Debug \
  -destination 'platform=iOS,name=Pebble' \
  -allowProvisioningUpdates build
```

---

## 6) Xcode Console Errors (From Device Run)

### Benign / Ignorable Errors
These appear on every RealityKit AR app and are NOT bugs in our code:
- `Could not resolve material name 'engine:BuiltinRenderGraphResources/AR/...'` — RealityKit internal
- `FigApplicationStateMonitor signalled err=-19431` — system camera framework
- `PSO compilation completed for driver shader` — Metal shader compilation
- `asset string 'engine:throttleGhosted.rematerial' parse failed` — RealityKit internal
- `Video texture allocator is not initialized` — RealityKit startup
- `fopen failed for data file: errno = 2` — RealityKit cache, recovers automatically
- `TBB Global TLS count is not == 1` — Threading library
- `warning: using linearization / solving fallback` — RealityKit rendering
- `Failed to set override status for bind point component member` — RealityKit material binding
- `FigCaptureSourceRemote / FigXPCUtilities err=-17281` — camera subsystem

### Real Errors (The 3 Bugs)
- `nw_write_request_report [Cn] Send failed with error "Socket is not connected"` — **BUG-3**
- `Gesture: System gesture gate timed out` — downstream of BUG-1/BUG-2
- "Gemini Live session timed out" banner in the UI — **BUG-3**

---

## 7) Priority Order

1. **Fix BUG-3 first** (Gemini WebSocket) — most impactful. Without it: no conversation, no audio, no demo.
   - Test API key validity via curl
   - Ensure WiFi (not just cellular)
   - Debug the URLSessionWebSocketDelegate flow
   
2. **Fix BUG-2** (Lion head-down) — likely a simple rotation correction after loading.

3. **Fix BUG-1** (Sultan invisible) — debug the Entity scene graph, check if mesh children are loading.

4. **After all 3 bugs fixed** — run full end-to-end test (T-G01):
   - Characters appear correctly
   - Gemini greets proactively
   - Voice conversation works
   - Lion roars on `[LION_ROAR]`
   - VR transition on `[VR_SCENE]`
   
5. **Demo rehearsal** (T-G03) — run through demo script from BRD Section 12.

---

## 8) Key Files to Edit

For the 3 bugs, you will primarily work in:

1. **`UtamaAI/AR/CharacterManager.swift`** (335 lines) — BUG-1 and BUG-2
   - `loadCharacterEntity()` at ~line 282 — entity loading logic
   - `placeCharacters()` at ~line 94 — positioning and scaling
   - `scaleEntity()` at ~line 271 — height-based scaling

2. **`UtamaAI/Voice/GeminiLiveSession.swift`** (380 lines) — BUG-3
   - `init()` at ~line 30 — URLSession creation with delegate
   - `openSocket()` at ~line 83 — WebSocket task creation
   - `sendSetupMessage()` at ~line 120 — Gemini protocol setup JSON
   - `URLSessionWebSocketDelegate` extension at ~line 320 — connection lifecycle

3. **`UtamaAI/Config/CharacterPrompts.swift`** (82 lines) — API key verification
   - `apiKey` computed property — currently has hardcoded fallback

---

## 9) USDZ Asset Origins (If Re-Export Needed)

| Asset | Source | Location | Notes |
|-------|--------|----------|-------|
| Sultan (utama.usdz) | CGTrader → Mixamo rigged | `SULTANASSETS/` | 5 anims: Idle, Talking, Gesture, Bow, Dance |
| Lion (lion.usdz) | CGTrader "Lion@Bite" pre-rigged | `LIONASSETS/uploads_files_6678807_Lion@Bite/` | 6 anims: Idle, Roar, Walk, Run, Resting, Bite |
| Conversion scripts | Python/Blender | `Scripts/convert_*.py` | Uses Blender 5.0.1 Python API |

Previous fix history:
- **Pink textures**: TIF/TGA → PNG (iOS doesn't support TIF/TGA in USDZ)
- **Lion warping**: Used action transfer instead of armature re-parenting
- **Lion animation not playing**: Added missing Armature modifier before Blender USD export

---

*End of Handoff — 3 bugs to fix, then the MVP demo is ready.*
