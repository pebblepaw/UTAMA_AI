# Utama AI — Technology Research Report
> Compiled: March 2026 | For: Hackathon MVP — AR Historical Characters App

---

## Table of Contents
1. [Google Gemini Multimodal Live API](#1-google-gemini-multimodal-live-api)
2. [Google Cloud STT/TTS vs. Gemini Native Audio](#2-google-cloud-stt-tts-vs-gemini-native-audio)
3. [Google VEO (Video Generation)](#3-google-veo-video-generation)
4. [ARKit + RealityKit (iOS)](#4-arkit--realitykit-ios)
5. [3D Asset Sources for Quick MVP](#5-3d-asset-sources-for-quick-mvp)
6. [Audio Playback in AR (iOS)](#6-audio-playback-in-ar-ios)

---

## 1. Google Gemini Multimodal Live API

### Overview
The Live API enables **low-latency, real-time voice and video interactions** with Gemini. It processes continuous streams of audio, video, or text and delivers immediate, human-like spoken responses via a persistent WebSocket connection. This is the single most important API for our MVP — it replaces the need for separate STT, LLM, and TTS services.

### How WebSocket-Based Real-Time Streaming Works

**Connection Architecture:**
- The client opens a **WebSocket** connection to `generativelanguage.googleapis.com`
- Two implementation approaches:
  - **Server-to-server**: Your backend connects to Live API via WebSocket. Client sends audio/video to your server, which forwards it to Gemini.
  - **Client-to-server** (recommended for latency): Frontend connects directly to Live API via WebSocket, bypassing your backend. Use **ephemeral tokens** instead of API keys for security.

**Data Flow:**
1. Client connects via WebSocket with a setup message (model, config, system instructions)
2. Client streams raw audio (16-bit PCM, 16kHz mono) and/or video frames to the WebSocket
3. Server automatically detects speech via **Voice Activity Detection (VAD)**
4. Server streams back audio response chunks (24kHz PCM) in real-time
5. Client plays audio chunks as they arrive for sub-second perceived latency

**Key WebSocket Messages:**
- `send_realtime_input(audio=...)` — stream mic audio (optimized for responsiveness)
- `send_client_content(turns=..., turn_complete=True)` — send text or restore context
- `session.receive()` — async iterator yielding response chunks
- Interruption handling: when VAD detects user speaking during model output, generation is cancelled

**Code Pattern (Python reference, adaptable to Swift WebSocket):**
```python
MODEL = "gemini-2.5-flash-native-audio-preview-12-2025"
CONFIG = {
    "response_modalities": ["AUDIO"],
    "system_instruction": "You are Sang Nila Utama, a 14th century prince...",
    "speech_config": {
        "voice_config": {"prebuilt_voice_config": {"voice_name": "Kore"}}
    },
}

async with client.aio.live.connect(model=MODEL, config=CONFIG) as session:
    # Stream audio in
    await session.send_realtime_input(audio={"data": pcm_bytes, "mime_type": "audio/pcm"})
    
    # Receive audio out
    async for response in session.receive():
        if response.server_content and response.server_content.model_turn:
            for part in response.server_content.model_turn.parts:
                if part.inline_data and isinstance(part.inline_data.data, bytes):
                    play_audio(part.inline_data.data)
```

### Input/Output Modalities

| Direction | Modality | Details |
|-----------|----------|---------|
| **Input** | Audio | 16-bit PCM, 16kHz mono (will resample other rates). MIME: `audio/pcm;rate=16000` |
| **Input** | Video | Camera frames streamed to the API (JPEG/PNG frames) |
| **Input** | Text | Via `send_client_content()` |
| **Output** | Audio | 24kHz PCM, 16-bit, mono. Streamed in chunks. |
| **Output** | Text | Alternative to audio (one modality per session — TEXT **or** AUDIO, not both) |

**Critical limitation:** You can only set ONE response modality per session — either `TEXT` or `AUDIO`. For our MVP, we want `AUDIO`.

### Supported Models

| Model | ID String | Best For |
|-------|-----------|----------|
| **Gemini 2.5 Flash Live Preview** (RECOMMENDED) | `gemini-2.5-flash-native-audio-preview-12-2025` | Real-time conversational agents with sub-second native audio streaming. **Best for our MVP.** |
| Gemini Live 2.5 Flash Preview | `gemini-live-2.5-flash-preview` | Text-mode Live API (no native audio) |
| Gemini 2.5 Flash | `gemini-2.5-flash` | Standard non-live use |
| Gemini 2.5 Pro | `gemini-2.5-pro` | Complex tasks (not optimized for live) |

**For our MVP: Use `gemini-2.5-flash-native-audio-preview-12-2025`** — it's the flagship Live API model with native audio reasoning.

### System Instructions / Persona Prompts

System instructions are set in the **session configuration** at connection time:

```python
CONFIG = {
    "response_modalities": ["AUDIO"],
    "system_instruction": """You are Sang Nila Utama, a Srivijayan prince from the 13th century. 
    You are standing on the shore of Temasek (modern-day Singapore). 
    You speak with wisdom and regal bearing. You saw a majestic lion on this shore, 
    which inspired you to name this island 'Singapura' — Lion City.
    Speak in English with occasional Malay phrases. Be warm, wise, and historically authentic.
    Keep responses conversational and under 30 seconds of speech.""",
    "speech_config": {
        "voice_config": {"prebuilt_voice_config": {"voice_name": "Charon"}}
    },
}
```

**Key points:**
- System instructions are set once at connection time, not per-message
- You can restrict language output via system instructions
- The model supports **70 languages** and auto-detects input language
- Native audio models naturally switch languages

### Voice Selection

30 prebuilt voices available. Recommended for historical character:

| Voice | Style | Good For |
|-------|-------|----------|
| **Charon** | Informative | Wise narrator/historical figure |
| **Orus** | Firm | Authoritative ruler |
| **Fenrir** | Excitable | Animated storyteller |
| **Puck** | Upbeat | Friendly guide |
| **Achird** | Friendly | Warm conversationalist |
| **Rasalgethi** | Informative | Scholarly character |
| **Sadaltager** | Knowledgeable | Expert/sage |

### Advanced Native Audio Features

- **Affective Dialog** (`enable_affective_dialog: true`): Adapts response style to user's emotional tone (requires `v1alpha` API version)
- **Proactive Audio** (`proactive_audio: true`): Model decides when NOT to respond if irrelevant
- **Thinking** (`thinking_config`): Dynamic thinking enabled by default; can set `thinking_budget` tokens
- **Audio Transcription**: Both input and output audio can be transcribed simultaneously:
  - `output_audio_transcription: {}` — get text of what the model says
  - `input_audio_transcription: {}` — get text of what the user says
  - Useful for: subtitle display, logging, triggering animations based on text content

### VAD (Voice Activity Detection) Configuration

```python
config = {
    "realtime_input_config": {
        "automatic_activity_detection": {
            "disabled": False,
            "start_of_speech_sensitivity": "START_SENSITIVITY_LOW",
            "end_of_speech_sensitivity": "END_SENSITIVITY_LOW",
            "prefix_padding_ms": 20,
            "silence_duration_ms": 100,
        }
    }
}
```

- **Automatic VAD** (default): Model detects speech start/end automatically
- **Manual VAD**: Disable auto-VAD and send `activity_start` / `activity_end` signals (if you want iOS-side control)
- When VAD detects user interrupting model speech, generation is cancelled and only already-sent audio is kept

### Latency Characteristics

- **Connection**: WebSocket handshake + setup message exchange (~100-300ms)
- **First audio chunk**: Sub-second after user finishes speaking (with native audio model)
- **Streaming**: Audio chunks arrive continuously, enabling real-time playback
- **End-to-end perceived latency**: ~300-800ms for native audio model (comparable to human conversation)
- **Thinking**: If thinking is enabled, first response may take slightly longer but quality improves
- **Tip**: Client-to-server approach has lower latency than server-to-server since it skips the relay hop

### Session Limits

| Constraint | Value |
|-----------|-------|
| Audio-only session | 15 minutes max |
| Audio + video session | 2 minutes max |
| Context window (native audio) | 128k tokens |
| Context window (other Live models) | 32k tokens |
| Response modalities | ONE per session (TEXT or AUDIO) |

**For longer sessions**, use session management techniques: session resumption via context summaries, or reconnect with prior context.

### Integration from Native iOS (Swift) via WebSocket

**There is no official Google Gen AI SDK for Swift.** You must connect via raw WebSocket.

**Approach:**
1. Use `URLSessionWebSocketTask` (native iOS 13+ WebSocket) or a library like **Starscream**
2. Connect to: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=YOUR_API_KEY`
3. Send a setup message (JSON) as the first frame
4. Stream audio as binary frames (raw PCM)
5. Receive JSON + binary audio frames back

**Swift WebSocket skeleton:**
```swift
import Foundation
import AVFoundation

class GeminiLiveSession {
    private var webSocket: URLSessionWebSocketTask?
    private let apiKey: String
    private let audioEngine = AVAudioEngine()
    
    // Audio format constants
    let inputSampleRate: Double = 16000
    let outputSampleRate: Double = 24000
    
    func connect() {
        let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)")!
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Send setup message
        let setup: [String: Any] = [
            "setup": [
                "model": "models/gemini-2.5-flash-native-audio-preview-12-2025",
                "generation_config": [
                    "response_modalities": ["AUDIO"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": [
                                "voice_name": "Charon"
                            ]
                        ]
                    ]
                ],
                "system_instruction": [
                    "parts": [["text": "You are Sang Nila Utama..."]]
                ]
            ]
        ]
        
        let data = try! JSONSerialization.data(withJSONObject: setup)
        webSocket?.send(.string(String(data: data, encoding: .utf8)!)) { error in
            if let error { print("Setup error: \(error)") }
        }
        
        receiveMessages()
    }
    
    func sendAudio(_ pcmData: Data) {
        // Wrap PCM data in the realtime_input message format
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    ["mime_type": "audio/pcm;rate=16000", "data": pcmData.base64EncodedString()]
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: message)
        webSocket?.send(.string(String(data: data, encoding: .utf8)!)) { _ in }
    }
    
    func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                // Parse JSON response, extract audio data from inline_data
                self?.handleResponse(text)
            case .success(.data(let data)):
                // Binary audio frame
                self?.playAudio(data)
            case .failure(let error):
                print("Receive error: \(error)")
            }
            self?.receiveMessages() // Continue listening
        }
    }
    
    func handleResponse(_ json: String) {
        // Parse serverContent.modelTurn.parts[].inlineData.data (base64 PCM)
        // Decode base64 -> PCM bytes -> feed to AVAudioPlayerNode
    }
}
```

**For production:** Use **ephemeral tokens** instead of API keys. Generate a short-lived token server-side, pass to client.

**Alternative approach:** Use the [Pipecat (by Daily)](https://docs.pipecat.ai/guides/features/gemini-live) or [LiveKit](https://docs.livekit.io/agents/models/realtime/plugins/gemini/) frameworks which handle WebSocket/WebRTC transport and have iOS SDKs.

---

## 2. Google Cloud STT/TTS vs. Gemini Native Audio

### The Key Question: Do You Need Separate STT/TTS?

**NO — for the MVP, Gemini Live API handles everything natively.**

| Capability | Gemini Live API (Native Audio) | Separate STT + LLM + TTS |
|-----------|-------------------------------|--------------------------|
| Speech-to-Text | ✅ Built-in (audio input → understanding) | Google Cloud STT v2 |
| Language Model | ✅ Built-in (Gemini reasoning) | Separate Gemini API call |
| Text-to-Speech | ✅ Built-in (native audio output) | Google Cloud TTS or Gemini TTS |
| Latency | ~300-800ms end-to-end | ~2-4 seconds (3 API calls chained) |
| Complexity | Single WebSocket connection | 3 separate API integrations |
| Voice quality | High-quality native voices (30 options) | Cloud TTS: very high quality (WaveNet/Neural2) |

**Recommendation: Use Gemini Live API as your single integration for the MVP. It handles audio-in → reasoning → audio-out in one WebSocket.**

### When You Might Need Separate Services

- **Gemini TTS models** (`gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`): For pre-recorded narration, intros, or offline audio generation. Supports multi-speaker TTS (up to 2 speakers). More control over style/accent via prompting.
- **Google Cloud Speech-to-Text v2**: If you need offline transcription, speaker diarization, or custom vocabulary for domain-specific terms (e.g., Malay historical terms). Latest v2 API supports chirp_2 model, automatic punctuation, multi-channel audio.
- **Google Cloud Text-to-Speech**: If you want WaveNet or Neural2 voices, SSML control, or need to pre-generate audio assets. Supports custom voice cloning (for premium tier).

### Gemini TTS (Standalone) Details

- Models: `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`
- 30 prebuilt voices (same voices available in Live API)
- Output: 24kHz PCM (wavefile)
- Multi-speaker: Up to 2 speakers with `MultiSpeakerVoiceConfig`
- Controllable via natural language prompts (accent, pace, emotion, whispering, etc.)
- 73+ languages supported
- Context window: 32k tokens
- Good for: Pre-generating intro narrations, scene transitions

### Voice Customization Options

**In Live API:**
- Choose from 30 prebuilt voices
- System instructions influence tone/personality
- Affective dialog adapts to user emotion

**In Gemini TTS (standalone):**
- Full prompt control: Audio Profile, Scene, Director's Notes
- Accent control ("British English as heard in Croydon")
- Pace control ("Incredibly slow and liquid")
- Style control ("Vocal smile", "sassy", "whisper")
- Paralinguistic features (breathiness, projection)

---

## 3. Google VEO (Video Generation)

### Current State (March 2026)

**Veo 3.1** is Google's state-of-the-art video generation model, available via Gemini API.

### Capabilities

| Feature | Details |
|---------|---------|
| Model ID | `veo-3.1-generate-preview` |
| Video duration | 4, 6, or 8 seconds |
| Resolution | 720p (default), 1080p, 4K |
| Aspect ratio | 16:9 (landscape), 9:16 (portrait) |
| Frame rate | 24fps |
| Audio | **Natively generated** with video (dialogue, SFX, ambient) |
| Input types | Text-to-video, Image-to-video, Video extension, Interpolation, Reference images |
| Videos per request | 1 |
| Reference images | Up to 3 (for subject consistency) |
| Video extension | Up to 20 extensions, max 148 seconds total, 720p only |
| Status | Preview |

### Can It Generate Short Cinematic Scenes?

**YES, absolutely.** Veo 3.1 excels at cinematic scenes and supports:
- Dialogue in video (characters speaking with synced audio)
- Sound effects and ambient audio
- Wide range of visual styles (realism, cartoon, anime, film noir, etc.)
- Camera movements (dolly, tracking, aerial, POV)
- Portrait and landscape

**Example prompt for our use case:**
```
A cinematic wide shot of an ancient Southeast Asian prince in royal golden attire 
standing on a tropical beach shore. He spots a majestic lion emerging from the jungle. 
The prince speaks in awe, "Singapura..." The lion roars majestically. 
Golden sunset light, warm tones, epic historical drama style.
```

### How to Access

**Via Gemini API (recommended):**
```python
from google import genai
from google.genai import types
import time

client = genai.Client()  # Uses GOOGLE_API_KEY env var

operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    prompt="A cinematic shot of a majestic lion on a tropical beach at sunset...",
    config=types.GenerateVideosConfig(
        aspect_ratio="16:9",
        resolution="1080p",  # or "720p", "4k"
    ),
)

# Poll for completion (11 seconds to 6 minutes)
while not operation.done:
    time.sleep(10)
    operation = client.operations.get(operation)

video = operation.response.generated_videos[0]
client.files.download(file=video.video)
video.video.save("scene.mp4")
```

**Also available via:**
- Google AI Studio (UI): [aistudio.google.com](https://aistudio.google.com)
- Vertex AI (enterprise)
- Veo Studio applet in AI Studio

### Latency & Limitations

| Metric | Value |
|--------|-------|
| Minimum generation time | ~11 seconds |
| Maximum generation time | ~6 minutes (peak hours) |
| Video retention | 2 days on server (must download) |
| Watermarking | SynthID watermark applied automatically |
| Person generation | `allow_all` for text-to-video |
| Extension input | Must be Veo-generated video, 720p only |

### For Our MVP: VR Scene Transition

**Plan:** Pre-generate the lion encounter scene using Veo 3.1 before the hackathon demo, or generate it during the experience with a loading screen (~30s wait).

- Generate an 8-second cinematic scene of the lion encounter
- Use 1080p, 16:9 for immersive fullscreen playback
- Audio will be natively generated (lion roar, ambient jungle sounds)
- Can extend to ~16 seconds by chaining one extension
- Store the video locally in the app bundle for instant playback, or generate on-demand

---

## 4. ARKit + RealityKit (iOS)

### Plane Detection & Anchor Placement

**ARKit provides world tracking with plane detection out of the box.**

```swift
import ARKit
import RealityKit

// In your ARView setup
let arView = ARView(frame: .zero)

// Configure session for plane detection
let config = ARWorldTrackingConfiguration()
config.planeDetection = [.horizontal]  // Detect floors, tables
config.environmentTexturing = .automatic
arView.session.run(config)

// Place anchor on detected plane
// Option 1: Raycasting (user taps to place)
func placeCharacter(at point: CGPoint) {
    let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
    if let firstResult = results.first {
        let anchor = AnchorEntity(raycastResult: firstResult)
        anchor.addChild(characterEntity)
        arView.scene.addAnchor(anchor)
    }
}

// Option 2: Auto-place on first detected plane
// Use ARSessionDelegate to detect planes, then place when ready
func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    for anchor in anchors {
        if let planeAnchor = anchor as? ARPlaneAnchor,
           planeAnchor.alignment == .horizontal {
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            anchorEntity.addChild(characterEntity)
            arView.scene.addAnchor(anchorEntity)
        }
    }
}
```

### Loading USDZ / Reality Files

```swift
// Load USDZ model
let characterEntity = try! Entity.load(named: "SangNilaUtama.usdz")

// Load from URL (async)
Entity.loadAsync(contentsOf: modelURL)
    .sink(receiveCompletion: { _ in },
          receiveValue: { entity in
              anchor.addChild(entity)
          })
    .store(in: &cancellables)

// Load Reality file (from Reality Composer Pro)
let scene = try! Experience.loadScene()
let character = scene.findEntity(named: "character")

// Scale and position
characterEntity.scale = SIMD3<Float>(repeating: 0.01)  // Adjust scale
characterEntity.position = SIMD3<Float>(0, 0, -1.5)    // 1.5m in front
characterEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])  // Face camera
```

**Supported formats:**
- `.usdz` — Apple's preferred AR format (Universal Scene Description, zipped)
- `.reality` — Reality Composer Pro format (can include behaviors, animations)
- Models can include PBR materials, animations, skeletons

### Animating 3D Characters

**Built-in animation playback (from USDZ):**
```swift
// Play all animations in the model
if let animationResource = characterEntity.availableAnimations.first {
    characterEntity.playAnimation(animationResource.repeat())
}

// Play named animation
for animation in characterEntity.availableAnimations {
    if animation.name == "idle" {
        characterEntity.playAnimation(animation.repeat())
    }
}

// Transition between animations
characterEntity.stopAllAnimations()
let talkAnim = characterEntity.availableAnimations.first { $0.name == "talking" }
characterEntity.playAnimation(talkAnim!.repeat(), transitionDuration: 0.3)
```

**Animation types for MVP:**
1. **Idle**: Breathing, subtle weight shift, looking around
2. **Talking**: Gesturing with hands, body movement (not lip-sync)
3. **Gesturing**: Pointing, arms spread, dramatic poses
4. **Reaction**: Nodding, surprise, laughter body movement

### Lip-Sync / Mouth Animation Approaches

This is the **hardest part** for an MVP. Options ranked by feasibility:

**Option 1: No Lip-Sync (Easiest — RECOMMENDED for MVP)**
- Use full-body "talking" animation from Mixamo that includes generic mouth movement
- The talking animation + audio playing simultaneously creates sufficient illusion
- Many successful AR apps use this approach

**Option 2: Blend Shape Animation (Medium Difficulty)**
- If the 3D model has facial blend shapes (visemes): A, E, I, O, U, etc.
- Parse audio amplitude or use Apple's `AVSpeechSynthesizer` phoneme callbacks
- Map phonemes to blend shapes in real-time
- RealityKit does NOT natively support blend shape animation (as of early 2026)
- Would need to use SceneKit or Metal for blend shape morphing

**Option 3: Simple Jaw Movement (Good Compromise)**
- Detect audio amplitude from the Gemini audio stream
- Map amplitude to a single jaw bone rotation on the character
- Requires the model to have a rigged jaw bone
```swift
// Pseudo-code for amplitude-based jaw
func updateJawFromAudio(amplitude: Float) {
    let jawRotation = simd_quatf(angle: amplitude * 0.3, axis: [1, 0, 0])
    jawBoneEntity.orientation = jawRotation
}
```

**Option 4: ARKit Face Tracking (Not Applicable)**
- Tracks the USER's face, not a virtual character's
- Could theoretically mirror user expressions onto character, but not useful for TTS

**Recommendation for MVP: Option 1 (talking body animation) + Option 3 (simple jaw movement if model has rigged jaw)**

### AR Overlay on Camera Feed

**ARView is the standard approach — it automatically overlays 3D on the camera feed:**

```swift
import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR is camera-based by default
        // The camera feed is the background
        // 3D entities render on top with proper occlusion & lighting
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // Add coaching overlay for guided placement
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}
```

### SwiftUI Integration with RealityKit

```swift
import SwiftUI
import RealityKit
import Combine

struct ContentView: View {
    @StateObject private var arManager = ARManager()
    @State private var isListening = false
    
    var body: some View {
        ZStack {
            // AR View as background
            ARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            // UI overlay
            VStack {
                Spacer()
                
                // Conversation UI
                if let transcript = arManager.lastTranscript {
                    Text(transcript)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                
                // Push-to-talk or auto-listen button
                Button(action: { arManager.toggleListening() }) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .padding()
                        .background(Circle().fill(isListening ? .red : .blue))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// UIViewRepresentable wrapper
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager
    
    func makeUIView(context: Context) -> ARView {
        return arManager.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}
```

### Key ARKit/RealityKit Facts for MVP

- **Minimum iOS**: ARKit requires iOS 11+, RealityKit requires iOS 13+, modern features need iOS 15+
- **Device requirement**: A12 Bionic or later (iPhone XS and newer) for world tracking
- **No external framework needed**: ARKit + RealityKit are Apple first-party frameworks
- **Environment texturing**: Automatic environment lighting makes AR objects look realistic
- **Occlusion**: People Occlusion available on A12+ (person walks in front of AR object)
- **Coaching overlay**: `ARCoachingOverlayView` guides users to scan their environment

---

## 5. 3D Asset Sources for Quick MVP

### CGTrader
- **URL**: [cgtrader.com](https://www.cgtrader.com)
- **Cultural/Historical Models**: Search "historical warrior", "southeast asian", "medieval prince", "royalty character"
- **Formats**: FBX, OBJ, GLTF, some USDZ
- **Price range**: $5-$100 for character models
- **Rigged models**: Many available pre-rigged for animation
- **Pros**: Large marketplace, quality varies but many professional models
- **Cons**: No auto-animation; need to bring your own animations
- **For our MVP**: Search "ancient warrior rigged" or "prince character rigged" — expect $20-50 for a decent rigged model

### Mixamo (by Adobe)
- **URL**: [mixamo.com](https://www.mixamo.com)
- **ACCESS**: **FREE** — requires Adobe account
- **Key Capability**: Upload ANY rigged character → auto-rig → apply animations from library
- **Animation Library**: 2,500+ motion-captured animations including:
  - **Idle**: `Idle`, `Happy Idle`, `Weight Shift`, `Breathing Idle`
  - **Talking**: `Talking`, `Talking_1`, `Talking_2` (hand gestures while speaking)
  - **Gesturing**: `Pointing`, `Arm Spread`, `Waving`, `Clapping`
  - **Walking**: Various walk cycles
  - **Reacting**: `Surprised`, `Head Nod`, `Bow`
- **Output formats**: FBX (with or without skin)
- **Workflow for our MVP**:
  1. Get a character model (from CGTrader or any source)
  2. Upload to Mixamo → auto-rigging
  3. Apply "Idle", "Talking", "Gesturing" animations
  4. Download as FBX
  5. Convert to USDZ via Reality Converter
- **Limitations**: Characters are humanoid only; no animal rigging (no lion)

### Ready Player Me
- **URL**: [readyplayer.me](https://readyplayer.me)
- **SDK**: Available for Unity, Unreal, Web (JavaScript)
- **iOS SDK**: Available via Swift Package Manager
- **Capability**: Generate customizable humanoid avatars
- **Output**: GLB (glTF binary) format
- **Animation**: Compatible with Mixamo animations (standard humanoid rig)
- **For our MVP**: Could generate a quick Sang Nila Utama-like avatar
  - Customize skin tone, hair, outfit
  - Limited to modern-ish clothing options (may not have historical Southeast Asian attire)
  - Best as a fallback if you can't find a better pre-made model
- **Pricing**: Free tier available for development

### Sketchfab
- **URL**: [sketchfab.com](https://www.sketchfab.com)
- **USDZ Download**: ✅ Many models offer direct USDZ download
- **Search terms**: "lion animated", "warrior character", "historical prince"
- **Free models**: Many available under Creative Commons
- **Paid models**: $5-$100 range
- **Pros**: Preview in 3D in browser, many free options, direct USDZ support
- **Cons**: Quality varies widely; many models are not rigged
- **For lion model**: Search "lion animated" — several free/cheap options with walk and roar animations

### Converting FBX/GLB to USDZ

**Reality Converter (Apple's free tool):**
- **Download**: Free on Mac App Store (requires macOS 10.15+)
- **Input**: FBX, OBJ, GLTF, GLB, USD
- **Output**: USDZ
- **Features**: Preview materials/textures, adjust PBR properties, batch convert
- **Usage**: Drag-and-drop FBX → review materials → Export as USDZ

**Reality Composer Pro (Xcode tool):**
- Built into Xcode 15+
- More control over scenes, animations, behaviors
- Can combine multiple assets into a `.reality` scene

**Command line (usdzconvert from Apple):**
```bash
# Install Apple's USD tools
pip install usd-utils  # or download from Apple developer site

# Convert
usdzconvert model.fbx model.usdz
usdzconvert model.glb model.usdz --metersPerUnit 0.01
```

**Blender (free, most flexible):**
```
1. Import FBX/GLB into Blender
2. Verify rig, fix materials if needed
3. File → Export → Universal Scene Description (.usd, .usdc, .usdz)
4. Check "Export Animations"
```

**Typical pipeline for MVP:**
1. Download rigged character from CGTrader (FBX)
2. Upload to Mixamo, apply idle + talking animations
3. Download animated FBX from Mixamo
4. Open in Reality Converter → Export USDZ
5. Add to Xcode project

### Free/Cheap Lion 3D Models with Animations

**Best sources:**

1. **Sketchfab** — Search "lion animated"
   - Several free animated lions (walk, roar, idle)
   - Look for models with "Download" enabled and USDZ format
   - Example: "Low Poly Lion" by various artists (free, CC license)

2. **CGTrader** — Search "lion animated rigged"
   - Price: ~$10-30 for quality animated lion
   - Look for models with: idle, walk, roar animations
   - FBX format → convert to USDZ

3. **TurboSquid** — Search "lion animated"
   - Some free options, paid typically $15-50
   - Good quality rigged lions with multiple animations

4. **Free3D.com** — Search "lion"
   - Free options available, quality varies
   - May need retopology for AR performance

5. **Unity Asset Store** (if building via Unity path)
   - "African Animals Pack" — includes animated lion
   - Can export FBX from Unity → convert to USDZ

**Lion Animation Requirements for MVP:**
- Idle (standing, breathing) — most important
- Walk cycle — for entrance
- Roar — for the dramatic reveal moment
- Sit/lie down — optional, for idle state

**Tip:** A stylized/low-poly lion will perform better in AR and be easier to find for free.

---

## 6. Audio Playback in AR (iOS)

### Playing Streamed Audio from Gemini Response

The Gemini Live API returns **24kHz, 16-bit PCM** audio in chunks. You need to:

1. **Buffer incoming PCM chunks**
2. **Play them through `AVAudioEngine`** (low-latency, supports streaming)

```swift
import AVFoundation

class AudioStreamPlayer {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let outputFormat: AVAudioFormat
    
    init() {
        // Gemini outputs 24kHz, 16-bit, mono PCM
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: true
        )!
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        try! audioEngine.start()
        playerNode.play()
    }
    
    func enqueueAudioChunk(_ pcmData: Data) {
        let frameCount = UInt32(pcmData.count) / 2  // 16-bit = 2 bytes per sample
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        pcmData.withUnsafeBytes { rawPtr in
            let src = rawPtr.bindMemory(to: Int16.self)
            buffer.int16ChannelData?[0].update(from: src.baseAddress!, count: Int(frameCount))
        }
        
        playerNode.scheduleBuffer(buffer)
    }
    
    func stop() {
        playerNode.stop()
        audioEngine.stop()
    }
}
```

**Integration with Gemini WebSocket:**
```swift
// In your WebSocket receive handler:
func handleGeminiAudioResponse(_ base64Audio: String) {
    guard let pcmData = Data(base64Encoded: base64Audio) else { return }
    audioPlayer.enqueueAudioChunk(pcmData)
    
    // Also calculate amplitude for animation sync
    let amplitude = calculateRMSAmplitude(pcmData)
    DispatchQueue.main.async {
        self.arManager.updateCharacterMouthAnimation(amplitude: amplitude)
    }
}
```

### Spatial Audio in RealityKit

RealityKit supports **spatial audio** — sound appears to come from the 3D entity's position in AR space:

```swift
// Add spatial audio to character entity
let audioResource = try! AudioFileResource.load(
    named: "response.wav",
    configuration: AudioFileResource.Configuration(
        shouldLoop: false,
        shouldRandomizeStartTime: false
    )
)

// Create audio playback component
let audioPlayback = characterEntity.prepareAudio(audioResource)
audioPlayback.play()

// For streaming audio (Gemini responses), use a different approach:
// RealityKit's spatial audio works best with pre-loaded files.
// For real-time streaming, play through AVAudioEngine (non-spatial)
// and the illusion of spatial audio is maintained because the character
// is visually "speaking" in AR space.
```

**Practical consideration for MVP:**
- **Non-spatial audio** (AVAudioEngine direct playback) is simpler and sufficient for the MVP
- The visual alignment of the character moving their mouth + audio playing creates the spatial illusion
- True spatial audio adds complexity and is better for v2

### Syncing Audio with Character Animation

**Approach 1: Audio Amplitude → Animation State (RECOMMENDED)**

```swift
class AnimationSyncManager {
    var characterEntity: Entity?
    var isSpeaking = false
    
    // Called continuously while Gemini audio is playing
    func updateFromAudioAmplitude(_ amplitude: Float) {
        guard let character = characterEntity else { return }
        
        if amplitude > 0.05 && !isSpeaking {
            // Switch to talking animation
            isSpeaking = true
            switchToAnimation(named: "talking", on: character)
        } else if amplitude < 0.02 && isSpeaking {
            // Switch back to idle
            isSpeaking = false
            switchToAnimation(named: "idle", on: character)
        }
    }
    
    func switchToAnimation(named name: String, on entity: Entity) {
        entity.stopAllAnimations()
        if let anim = entity.availableAnimations.first(where: { $0.name == name }) {
            entity.playAnimation(anim.repeat(), transitionDuration: 0.3)
        }
    }
    
    // Calculate RMS amplitude from PCM data
    func calculateAmplitude(from pcmData: Data) -> Float {
        let samples = pcmData.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let rms = sqrt(samples.map { Float($0) * Float($0) }.reduce(0, +) / Float(samples.count))
        return rms / Float(Int16.max)  // Normalize to 0.0-1.0
    }
}
```

**Approach 2: Gemini Transcription → Animation Triggers**

Use `output_audio_transcription` from Gemini to get text of what the model is saying, then:
- Detect sentence boundaries → trigger gesture animations
- Detect question marks → trigger quizzical pose
- Detect exclamations → trigger dramatic gesture
- While any audio is playing → play talking animation
- During pauses → switch to idle

**Approach 3: Simple State Machine**

```
States:
  IDLE → (Gemini audio starts) → TALKING
  TALKING → (Gemini audio stops) → IDLE
  IDLE → (user taps) → LISTENING
  LISTENING → (user stops talking) → THINKING
  THINKING → (Gemini responds) → TALKING

Animations:
  IDLE: gentle breathing/weight shift loop
  TALKING: gesturing while speaking loop
  LISTENING: attentive pose, slight head tilt
  THINKING: hand on chin, looking up
```

### Complete Audio Pipeline for MVP

```
[User speaks into iPhone mic]
    ↓
[AVAudioEngine captures 16kHz PCM]
    ↓
[Stream to Gemini Live API via WebSocket]
    ↓
[Gemini processes audio + persona instructions]
    ↓
[Receives 24kHz PCM chunks via WebSocket]
    ↓ (parallel)
[AVAudioPlayerNode plays audio] + [Calculate amplitude → animate character]
    ↓
[User hears response from speaker] + [Character appears to speak in AR]
```

---

## Architecture Summary for Hackathon MVP

```
┌──────────────────────────────────────────────────────────────┐
│                    iOS App (Swift)                            │
│                                                              │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │   ARView        │  │  Gemini Live     │  │   Audio    │ │
│  │   (RealityKit)  │  │  WebSocket       │  │   Engine   │ │
│  │                 │  │                  │  │            │ │
│  │  • Plane detect │  │  • Connect       │  │  • Capture │ │
│  │  • USDZ models  │  │  • Stream mic    │  │  • Playback│ │
│  │  • Animations   │  │  • Receive audio │  │  • Amplitude│ │
│  │  • Character    │  │  • Transcription │  │            │ │
│  └────────┬────────┘  └────────┬─────────┘  └─────┬──────┘ │
│           │                    │                    │        │
│           └────────── Sync ────┴────────────────────┘        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              SwiftUI Overlay                            │ │
│  │  • Transcript bubbles • Record button • Scene controls  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────┐                                        │
│  │  VR Scene        │  Pre-generated Veo 3.1 video          │
│  │  (AVPlayer)      │  Fullscreen playback for transition    │
│  └──────────────────┘                                        │
└──────────────────────────────────────────────────────────────┘
            │
            │ WebSocket (wss://)
            ▼
┌──────────────────────────────────────────┐
│  Gemini 2.5 Flash Native Audio           │
│  (Live API)                              │
│                                          │
│  • Audio-in → Understanding → Audio-out  │
│  • System instruction: Sang Nila Utama   │
│  • Voice: Charon / Orus                  │
│  • VAD: Automatic                        │
│  • Transcription: Enabled                │
└──────────────────────────────────────────┘
```

### Hackathon Execution Priority

1. **P0**: ARView + plane detection + load a USDZ character ← day 1 morning
2. **P0**: Gemini Live API WebSocket connection + audio in/out ← day 1 afternoon
3. **P0**: Play Gemini audio + animate character (idle/talking) ← day 1 evening
4. **P1**: System instructions / persona for Sang Nila Utama ← quick config
5. **P1**: VR scene transition (pre-generated Veo clip) ← pre-generate beforehand
6. **P1**: Lion model placement in AR ← add second USDZ
7. **P2**: Transcript overlay UI ← SwiftUI overlay
8. **P2**: Lip-sync / jaw animation ← if time permits
9. **P2**: Spatial audio ← nice-to-have
