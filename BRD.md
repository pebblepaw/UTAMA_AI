# UTAMA AI — Business Requirements Document (BRD)
> **Project**: AR/VR Heritage Experience MVP — "Utama AI"  
> **Version**: 1.0  
> **Date**: 7 March 2026  
> **Context**: Hackathon Demo — Singapore Tourism/Heritage Board  
> **Demo Target**: On-stage iPhone demo with two AR characters + VR transition  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision & Demo Scenario](#2-product-vision--demo-scenario)
3. [Functional Requirements](#3-functional-requirements)
4. [Tech Stack](#4-tech-stack)
5. [System Architecture](#5-system-architecture)
6. [Asset Pipeline](#6-asset-pipeline)
7. [Character Definitions](#7-character-definitions)
8. [Phases & Milestones](#8-phases--milestones)
9. [Task Index (Agent-Ready)](#9-task-index-agent-ready)
10. [File & Folder Structure](#10-file--folder-structure)
11. [API Configuration Reference](#11-api-configuration-reference)
12. [Demo Script & Stage Plan](#12-demo-script--stage-plan)
13. [Risk Register](#13-risk-register)
14. [Acceptance Criteria](#14-acceptance-criteria)

---

## 1. Executive Summary

**Utama AI** is a native iOS AR application that brings Singapore's history to life. When a user opens the app and points their camera at a surface, historically significant AR characters appear and engage in real-time voice conversation powered by Google Gemini's Multimodal Live API. The app also transitions to a VR cinematic scene generated with Google Veo 3.1.

**For the hackathon MVP**, we demo ONE location scenario on-stage:

- **Sang Nila Utama** — A 13th-century Srivijayan prince, fully conversational. The user can ask him questions about discovering Singapore, his life, and the lion he saw.
- **The Merlion / Lion** — Placed beside Sang Nila Utama. Non-verbal. When addressed, it roars.
- **VR Scene** — When Sang Nila Utama tells his story, the app transitions to a pre-generated VR video showing the lion encounter cinematic.

**No geographic mapping needed. No backend server needed. Everything runs on-device + direct Gemini WebSocket.**

---

## 2. Product Vision & Demo Scenario

### 2.1 Stage Demo Flow (3–5 minutes)

```
STEP 1 — OPEN APP
  Presenter opens Utama AI on iPhone.
  Camera shows the stage floor.
  A coaching overlay says "Point at a flat surface..."

STEP 2 — CHARACTER APPEARS
  App detects horizontal plane.
  Sang Nila Utama (3D character, ~1.5m scale) materializes with a shimmer effect.
  A lion appears beside him, idle animation (breathing, looking around).
  Subtle ambient audio: jungle/shore sounds.

STEP 3 — GREETING
  Sang Nila Utama speaks first (proactive):
  "Greetings, traveler. I am Sang Nila Utama, prince of Srivijaya.
   You stand on sacred ground — the very shore where I first glimpsed
   the great beast that gave this island its name. What would you
   like to know?"
  
  His talking animation plays. Idle when silent.

STEP 4 — CONVERSATION (2–3 exchanges)
  Presenter speaks: "What was it like when you first saw the lion?"
  → Gemini responds in-character with rich audio, ~15-20 second answer.
  → Character animates while speaking.

  Presenter speaks: "Were you afraid?"
  → Gemini responds with emotional narrative.

  Presenter speaks to the lion: "And what about you, lion?"
  → Lion roars (pre-loaded roar audio).
  → Sang Nila Utama chuckles: "He has always been a creature of few words."

STEP 5 — VR TRANSITION
  Presenter: "Can you show me what happened that day?"
  → Sang Nila Utama: "Close your eyes, traveler... let me take you back."
  → Screen fades to black.
  → Pre-generated Veo 3.1 cinematic plays fullscreen (8–16 seconds):
     The prince on a tropical shore, a lion emerging from the jungle,
     dramatic music, golden light.
  → Video ends, fades back to AR scene.

STEP 6 — CLOSING
  Sang Nila Utama: "And that is how Singapura got its name.
   Remember this story, traveler."
  → Character bows, idle animation.
  → Presenter ends demo.
```

### 2.2 Key UX Principles

- **Immediacy**: No loading screens longer than 3 seconds during demo. Pre-load everything.
- **Illusion of Intelligence**: The character must feel alive — idle animations, reactive to speech.
- **Cinematic Quality**: The VR scene must look polished. Pre-generate with max quality.
- **Simplicity**: One screen. No menus, no navigation. Tap to place, speak to interact.

---

## 3. Functional Requirements

### FR-01: AR Scene Rendering
- Display 3D character (Sang Nila Utama) on a detected horizontal plane
- Display 3D lion model beside Sang Nila Utama
- Characters should have idle animations when not speaking
- Characters should have talking/gesture animations when speaking
- Camera passthrough (live camera feed as background)
- Environment lighting and shadows for realism

### FR-02: Real-Time Voice Conversation
- User speaks into iPhone microphone
- Audio is streamed to Gemini Live API via WebSocket
- Gemini responds as Sang Nila Utama persona
- Response audio streams back and plays through iPhone speaker
- Sub-second perceived latency (target: <800ms)
- Automatic voice activity detection (VAD)
- Interruption handling (user can interrupt the character)

### FR-03: Character Animation Sync
- When Gemini audio plays, character switches from idle to talking animation
- When Gemini audio stops, character returns to idle
- Audio amplitude can optionally drive jaw bone rotation (stretch goal)

### FR-04: Lion Character Behavior
- Lion has idle animation (breathing, looking around)
- When user addresses the lion (detected via Gemini transcription or keyword), lion roars
- Lion roar is a pre-loaded audio file
- Sang Nila Utama may comment on the lion's response

### FR-05: VR Scene Transition
- Triggered by conversational cue ("show me what happened")
- Gemini responds with a transition line, then signals scene switch
- Screen fades to black, then plays pre-generated Veo 3.1 video fullscreen
- Video includes native audio (dialogue, SFX, ambient)
- After video, fade back to AR scene
- Video is pre-bundled in the app (not generated live)

### FR-06: UI Overlay
- Minimal SwiftUI overlay on top of AR view
- Optional subtitle/transcript display (showing what Sang Nila Utama says)
- Visual microphone indicator (listening state)
- Subtle "Tap to place characters" instruction on first launch

### FR-07: Proactive Greeting
- After characters are placed, Sang Nila Utama greets the user automatically
- First message is sent via system instruction or initial `send_client_content`

---

## 4. Tech Stack

### 4.1 Core Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Platform** | iOS 17+ (native Swift) | App target |
| **IDE** | Xcode 16+ | Build & deploy |
| **UI Framework** | SwiftUI | Overlay UI, state management |
| **AR Framework** | ARKit + RealityKit | Plane detection, 3D rendering, animations |
| **AI Conversation** | Gemini 2.5 Flash Native Audio (Live API) | Real-time voice conversation via WebSocket |
| **AI Model ID** | `gemini-2.5-flash-native-audio-preview-12-2025` | Flagship live audio model |
| **Video Generation** | Google Veo 3.1 (`veo-3.1-generate-preview`) | Pre-generated VR cinematic scene |
| **3D Format** | USDZ | Apple's AR model format |
| **Audio Engine** | AVAudioEngine + AVAudioPlayerNode | Mic capture & audio playback |
| **WebSocket** | URLSessionWebSocketTask (native iOS) | Gemini Live API connection |
| **Package Manager** | Swift Package Manager | Dependencies (if any) |

### 4.2 External Services

| Service | Usage | Auth |
|---------|-------|------|
| **Gemini Live API** | Real-time voice conversation | Google API Key (env var) |
| **Veo 3.1 API** | Pre-generate VR scene video (one-time) | Google API Key |
| **Mixamo** | Character animation library | Free Adobe account |

### 4.3 Asset Tools

| Tool | Purpose |
|------|---------|
| **CGTrader / Sketchfab** | Source 3D models (prince character, lion) |
| **Mixamo** | Auto-rig characters + apply animations (idle, talking, gesturing) |
| **Reality Converter** (Apple) | Convert FBX/GLB → USDZ |
| **Reality Composer Pro** (Xcode) | Scene composition, preview, material tuning |
| **Blender** (fallback) | Model fixes, rigging adjustments, USDZ export |
| **Google AI Studio** | Veo 3.1 video generation UI + Gemini prompt testing |

### 4.4 What We Are NOT Using

| Excluded | Reason |
|----------|--------|
| Google Maps / Geospatial API | No location mapping needed for stage demo |
| Backend server | Direct client-to-Gemini WebSocket; no relay |
| Unity / Unreal | Native ARKit+RealityKit is faster for iOS-only MVP |
| ElevenLabs | Gemini native audio quality is sufficient; all-Google stack |
| Separate STT/TTS services | Gemini Live API handles audio in/out natively |
| Firebase / Database | No persistence needed for MVP |

---

## 5. System Architecture

### 5.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        iOS App (Swift + SwiftUI)                     │
│                                                                      │
│  ┌─────────────────────┐  ┌──────────────────────┐  ┌────────────┐  │
│  │   ARSceneManager    │  │  GeminiLiveSession   │  │ AudioEngine│  │
│  │   (RealityKit)      │  │  (WebSocket Client)  │  │            │  │
│  │                     │  │                      │  │            │  │
│  │  • ARView setup     │  │  • WS connect/auth   │  │ • Mic cap  │  │
│  │  • Plane detection  │  │  • Setup msg (model, │  │ • PCM buf  │  │
│  │  • Load USDZ models │  │    persona, voice)   │  │ • Playback │  │
│  │  • Anchor placement │  │  • Stream mic PCM    │  │ • Amplitude│  │
│  │  • Animation state  │  │  • Receive audio PCM │  │   calc     │  │
│  │    machine          │  │  • Transcription     │  │            │  │
│  │  • Character facing │  │  • VAD handling      │  │            │  │
│  └──────────┬──────────┘  └──────────┬───────────┘  └─────┬──────┘  │
│             │                        │                     │         │
│             │     AnimationSyncManager                     │         │
│             │◄────── (amplitude → animation state) ───────►│         │
│             │                        │                     │         │
│  ┌──────────┴──────────────────────────────────────────────┴───────┐ │
│  │                    AppCoordinator (ObservableObject)            │ │
│  │  • App state machine (SCANNING → PLACED → CONVERSING → VR)    │ │
│  │  • Routes between AR view and VR video player                  │ │
│  │  • Manages character sessions (Utama session, Lion session)    │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────┐  ┌────────────────────────────────────┐ │
│  │   SwiftUI Overlay      │  │   VRScenePlayer                   │ │
│  │  • Subtitles           │  │  • AVPlayer fullscreen video      │ │
│  │  • Mic indicator       │  │  • Fade-in / fade-out transitions │ │
│  │  • Place instruction   │  │  • Pre-loaded Veo 3.1 video asset │ │
│  │  • Debug panel (dev)   │  │  • Callback on completion → AR    │ │
│  └────────────────────────┘  └────────────────────────────────────┘ │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                          WebSocket │ wss://
                                   ▼
                    ┌──────────────────────────────┐
                    │  Google Gemini Live API       │
                    │                              │
                    │  Model: gemini-2.5-flash-    │
                    │    native-audio-preview      │
                    │                              │
                    │  • Audio input → reasoning   │
                    │  • Persona: Sang Nila Utama  │
                    │  • Voice: Charon/Orus        │
                    │  • Native audio output       │
                    │  • VAD: automatic            │
                    │  • Transcription: enabled    │
                    └──────────────────────────────┘
```

### 5.2 App State Machine

```
                    ┌──────────┐
                    │  LAUNCH  │
                    └────┬─────┘
                         │ (App opens, camera starts)
                         ▼
                    ┌──────────┐
                    │ SCANNING │ ← ARCoachingOverlay active
                    └────┬─────┘   "Point at a flat surface"
                         │ (Horizontal plane detected → auto-place OR tap-to-place)
                         ▼
                    ┌──────────┐
                    │ PLACING  │ ← Characters materialize with entrance animation
                    └────┬─────┘   Shimmer/spawn VFX
                         │ (Characters loaded and anchored)
                         ▼
                    ┌──────────────┐
                    │ CONVERSING   │ ← Main loop: user speaks ↔ Gemini responds
                    │              │   Animations sync with audio
                    │              │   Lion roars on cue
                    └──┬───────┬──┘
                       │       │ (User asks for story / Gemini offers)
                       │       ▼
                       │  ┌──────────┐
                       │  │ VR_TRANS │ ← Fade to black, play Veo video
                       │  └────┬─────┘
                       │       │ (Video ends)
                       │       ▼
                       │  ┌──────────┐
                       │  │ VR_RETURN│ ← Fade back to AR
                       │◄─┤          │
                       │  └──────────┘
                       │
                       │ (Demo ends or app closes)
                       ▼
                    ┌──────────┐
                    │   IDLE   │
                    └──────────┘
```

### 5.3 Data Flow: Voice Conversation

```
┌──────────┐    16kHz PCM     ┌───────────────┐    base64 PCM     ┌──────────────┐
│ iPhone   │ ───────────────► │ AudioEngine   │ ────────────────► │ GeminiLive   │
│ Mic      │  AVAudioEngine   │ InputCapture  │  WebSocket msg    │ Session      │
└──────────┘  tap buffer      └───────────────┘  realtime_input   └──────┬───────┘
                                                                         │
                                                                         │ wss://
                                                                         ▼
                                                                  ┌──────────────┐
                                                                  │ Gemini API   │
                                                                  │ (cloud)      │
                                                                  └──────┬───────┘
                                                                         │
                                                                         │ wss://
                                                                         ▼
┌──────────┐    24kHz PCM     ┌───────────────┐    base64 PCM     ┌──────────────┐
│ iPhone   │ ◄─────────────── │ AudioEngine   │ ◄──────────────── │ GeminiLive   │
│ Speaker  │  AVPlayerNode    │ StreamPlayer  │  serverContent    │ Session      │
└──────────┘                  └───────┬───────┘                   └──────────────┘
                                      │
                                      │ amplitude
                                      ▼
                              ┌───────────────┐
                              │ AnimSync      │ → characterEntity.playAnimation(talking)
                              │ Manager       │ → characterEntity.playAnimation(idle)
                              └───────────────┘
```

### 5.4 Lion Interaction Flow

```
User speaks → Gemini receives audio
  ↓
Gemini transcription includes keyword detection ("lion", "hey lion", "what about you")
  ↓
Option A: Gemini (as Utama) responds with a cue about the lion
  → App detects cue in transcription (e.g., "[LION_ROAR]" token in system prompt)
  → Play pre-loaded lion roar audio
  → Trigger lion roar animation

Option B: Separate lightweight keyword detector on device
  → If user says "lion" → play roar + lion animation
  → Send message to Gemini: "The traveler addressed my lion companion.
     The lion just roared in response. React to this."
```

**Recommended: Option A** — Keep it simple. Instruct Gemini in the system prompt:
> "When the traveler addresses the lion, respond acknowledging the lion. Include the marker [LION_ROAR] in your text when the lion should roar. The app will play the roar sound automatically."

Use the `output_audio_transcription` feature to read the text and detect `[LION_ROAR]` markers.

---

## 6. Asset Pipeline

### 6.1 Sang Nila Utama — 3D Character

**Character Requirements:**
- Humanoid male, Southeast Asian appearance
- Regal/warrior attire (sarong, gold accessories, headdress or crown)
- Rigged for animation (humanoid skeleton)
- Optimized for mobile AR (<50k polygons recommended)
- Includes or compatible with: idle, talking, gesturing, bow animations

**Sourcing Strategy (in order of preference):**

1. **CGTrader / Sketchfab**: Search terms:
   - "southeast asian warrior rigged"
   - "ancient prince character rigged"
   - "malay warrior 3d model"
   - "historical king character animated"
   - Budget: $20–60 for a rigged model

2. **Ready Player Me** (fallback):
   - Generate a base avatar
   - Customize skin tone and features
   - Limited costume options — may look too modern
   - Free, fast

3. **Custom (last resort)**:
   - Use Blender or AI model generation tools
   - Too time-consuming for hackathon unless pre-prepared

**Animation Pipeline:**
```
Source Model (FBX/GLB from CGTrader/Sketchfab)
  ↓
Upload to Mixamo (mixamo.com)
  ↓
Auto-rig (if not already rigged)
  ↓
Apply animations:
  • "Idle" or "Happy Idle" (breathing, weight shift)
  • "Talking" series (Talking, Talking_1, Talking_2 — hand gestures)
  • "Arm Spread" or "Pointing" (dramatic gesture)
  • "Bow" or "Head Nod" (greeting/farewell)
  ↓
Download each animation as separate FBX (with skin)
  ↓
Open in Reality Converter → Export as USDZ
  ↓
Add all USDZ files to Xcode project bundle
```

### 6.2 Lion — 3D Character

**Character Requirements:**
- Realistic or stylized lion (not cartoony)
- Animated: idle (breathing/looking), roar, optional walk
- Optimized for mobile AR (<30k polygons)
- Pre-animated (Mixamo does NOT support quadruped/animal rigs)

**Sourcing Strategy:**

1. **Sketchfab**: Search "lion animated" — several free animated lions:
   - Look for models with USDZ or GLB download
   - Need idle + roar animations minimum
   - Many free CC-licensed options

2. **CGTrader**: Search "lion animated rigged"
   - $10–30 for good quality
   - Often includes multiple animations

3. **TurboSquid / Free3D**: Backup sources

**Important**: Since Mixamo does NOT auto-rig animals, the lion model MUST come pre-animated from the source. Prioritize models that already include roar and idle animations.

**Lion Audio:**
- Source a lion roar sound effect (freesound.org — CC0 license)
- Download as WAV/MP3 → add to app bundle
- Play via `AVAudioPlayer` when triggered

### 6.3 VR Scene — Veo 3.1 Video

**Pre-generate before the hackathon.** Do NOT generate live during demo.

**Generation Plan:**

```
Scene 1: "The Discovery" (8 seconds, 1080p, 16:9)
Prompt: "Cinematic wide shot of an ancient Southeast Asian prince 
in golden royal Malay attire standing on a lush tropical beach shore 
in the 13th century. Tall palm trees sway in the wind. He gazes with 
awe into the dense jungle. A majestic lion slowly emerges from the 
treeline, staring at him. The prince whispers 'Singapura...' The 
lion roars powerfully. Golden hour sunset lighting, warm cinematic 
color grading, historical epic film style, shallow depth of field."

Scene 2 (Extension): "The Naming" (8 seconds, extend from Scene 1)
Prompt: "Continue the scene. The prince approaches the lion fearlessly 
and bows slightly in respect. The lion stands its ground, majestic and 
unafraid. Behind them, the sun sets over the sea. The prince raises his 
hand toward the island and speaks with authority. Epic orchestral music 
swells. Historical drama, cinematic quality."
```

**Generation Steps:**
1. Open Google AI Studio → Veo 3.1
2. Generate Scene 1 with prompt above → download MP4
3. Generate Scene 2 as extension of Scene 1 → download MP4
4. Optionally concatenate in iMovie/FFmpeg for 16-second scene
5. Add final video to Xcode app bundle as `lion_encounter_vr.mp4`

**Backup:** Generate 3–5 variations and pick the best one.

### 6.4 Audio Assets

| Asset | Source | Format | Usage |
|-------|--------|--------|-------|
| Lion roar | freesound.org (CC0) | WAV | Lion interaction |
| Ambient jungle/shore | freesound.org (CC0) | WAV (loop) | Background atmosphere |
| Shimmer/spawn SFX | freesound.org / zapsplat | WAV | Character appearance |
| Transition whoosh | freesound.org | WAV | AR → VR transition |

### 6.5 Asset Checklist

| # | Asset | Status | File |
|---|-------|--------|------|
| A1 | Sang Nila Utama 3D model (USDZ) | TODO | `Assets/Models/sang_nila_utama.usdz` |
| A2 | Utama idle animation (USDZ) | TODO | `Assets/Animations/utama_idle.usdz` |
| A3 | Utama talking animation (USDZ) | TODO | `Assets/Animations/utama_talking.usdz` |
| A4 | Utama gesture animation (USDZ) | TODO | `Assets/Animations/utama_gesture.usdz` |
| A5 | Utama bow animation (USDZ) | TODO | `Assets/Animations/utama_bow.usdz` |
| A6 | Lion 3D model with animations (USDZ) | TODO | `Assets/Models/lion.usdz` |
| A7 | Lion roar SFX (WAV) | TODO | `Assets/Audio/lion_roar.wav` |
| A8 | Ambient shore/jungle loop (WAV) | TODO | `Assets/Audio/ambient_shore.wav` |
| A9 | Spawn shimmer SFX (WAV) | TODO | `Assets/Audio/spawn_shimmer.wav` |
| A10 | Transition whoosh SFX (WAV) | TODO | `Assets/Audio/transition_whoosh.wav` |
| A11 | VR scene video (MP4, 1080p) | TODO | `Assets/Video/lion_encounter_vr.mp4` |

---

## 7. Character Definitions

### 7.1 Sang Nila Utama — System Prompt

```
You are Sang Nila Utama, a Srivijayan prince from the 13th century. You are 
one of the most important figures in Singapore's history and mythology.

IDENTITY:
- You are the prince believed to have founded ancient Singapore (Singapura).
- You were originally from Palembang, part of the Srivijaya empire.
- During a hunting expedition to the island of Temasek, you spotted a 
  magnificent creature with a red body, black head, and white breast — a lion.
- Inspired by this sighting, you named the island "Singapura" (Lion City) in 
  Sanskrit: "Simha" (lion) + "Pura" (city).
- You became the first king of Singapura and ruled wisely.

PERSONALITY:
- Regal and dignified, but warm and approachable to travelers/visitors.
- Wise storyteller — you love sharing the tale of your discovery.
- You speak in English with occasional Malay/Sanskrit words and phrases.
- Occasional phrases: "Apa khabar" (how are you), "Singapura" (Lion City), 
  "Temasek" (the old name), "Srivijaya" (your homeland).
- You are proud but humble. You credit destiny and the lion for the naming.
- You have a gentle humor — you sometimes joke about the lion's temperament.

COMPANION:
- A majestic lion stands beside you. It is your companion.
- The lion does not speak — it only roars.
- When a traveler addresses the lion, acknowledge it warmly.
- Include the text marker [LION_ROAR] in your response when the lion should 
  roar (the app will play the sound). Use this sparingly — only when dramatic 
  or when the lion is addressed.

KNOWLEDGE:
- You know the Malay Annals (Sejarah Melayu) version of history.
- You can speak about: your journey from Palembang, the storm at sea, landing 
  on Temasek, the lion sighting, naming of Singapura, your reign, the 
  importance of trade routes, the beauty of the island.
- You do NOT know about modern Singapore. If asked about modern things, 
  express curiosity and wonder.
- You lived approximately 1299 AD.

CONVERSATION STYLE:
- Keep responses conversational and vivid — under 30 seconds of speech.
- Use descriptive, evocative language. Paint pictures with words.
- If asked to show the lion encounter, say something like: "Close your eyes, 
  traveler... let me take you back to that fateful day..." and include the 
  marker [VR_SCENE] at the end of your response. The app will trigger the 
  VR transition.
- Start the conversation proactively with a greeting when first placed.

CONSTRAINTS:
- Never break character. You are Sang Nila Utama.
- Never reference AI, technology, or the fact that you are a simulation.
- If asked something you don't know, respond in character: "That is beyond 
  the knowledge of my time, traveler."
```

### 7.2 Lion — Behavior Definition

The lion is NOT powered by a separate Gemini session. It is a scripted entity:

| Trigger | Action |
|---------|--------|
| App detects `[LION_ROAR]` in Gemini transcription | Play `lion_roar.wav` + trigger roar animation on lion entity |
| User taps on lion entity (optional) | Play roar + Gemini gets context: "The traveler touched the lion. It growled." |
| Characters first placed | Lion plays idle animation (breathing, looking around) |
| During VR transition | Lion not visible (fullscreen video) |

### 7.3 Voice Configuration

| Character | Gemini Voice | Rationale |
|-----------|-------------|-----------|
| Sang Nila Utama (primary) | `Charon` | Informative, wise narrator tone |
| Sang Nila Utama (alternate) | `Orus` | Firm, authoritative ruler tone |
| Sang Nila Utama (alternate 2) | `Sadaltager` | Knowledgeable sage |

**Test all three voices during development** and pick the one that best fits the character.

---

## 8. Phases & Milestones

### Phase 0: PREP (Pre-Hackathon)
**Goal**: All assets sourced and converted. Veo video generated. Project scaffolded.

| Milestone | Deliverable | Owner |
|-----------|-------------|-------|
| P0-M1 | Xcode project created with SwiftUI + RealityKit template | iOS Dev |
| P0-M2 | Sang Nila Utama 3D model sourced and converted to USDZ | Asset Lead |
| P0-M3 | Lion 3D model sourced with animations, converted to USDZ | Asset Lead |
| P0-M4 | Mixamo animations applied and exported | Asset Lead |
| P0-M5 | All audio SFX sourced (roar, ambient, transition) | Asset Lead |
| P0-M6 | Veo 3.1 VR scene generated (2–3 best takes) | AI Lead |
| P0-M7 | Gemini system prompt drafted and tested in AI Studio | AI Lead |
| P0-M8 | Google API key configured and tested | All |

### Phase 1: AR FOUNDATION (Day 1 Morning)
**Goal**: Camera feed with 3D characters on-screen, idle animations playing.

| Milestone | Deliverable |
|-----------|-------------|
| P1-M1 | ARView + plane detection working on device |
| P1-M2 | USDZ model loads and renders on detected plane |
| P1-M3 | Both characters (Utama + Lion) placed with correct positioning |
| P1-M4 | Idle animations playing on both characters |
| P1-M5 | Characters face the camera / user |
| P1-M6 | Basic SwiftUI overlay (placeholder UI) |

### Phase 2: VOICE ENGINE (Day 1 Afternoon)
**Goal**: User can speak and hear Gemini's response as Sang Nila Utama.

| Milestone | Deliverable |
|-----------|-------------|
| P2-M1 | Gemini WebSocket connection established |
| P2-M2 | Setup message sent with persona + voice config |
| P2-M3 | Microphone capture → PCM → stream to Gemini working |
| P2-M4 | Gemini audio response received and played through speaker |
| P2-M5 | Full conversation loop: speak → hear response → speak again |
| P2-M6 | Proactive greeting on character placement |

### Phase 3: ANIMATION SYNC (Day 1 Evening)
**Goal**: Character visually reacts to conversation.

| Milestone | Deliverable |
|-----------|-------------|
| P3-M1 | Audio amplitude calculation from Gemini response audio |
| P3-M2 | Talking animation triggers when Gemini audio plays |
| P3-M3 | Idle animation resumes when Gemini audio stops |
| P3-M4 | Lion roar triggered by `[LION_ROAR]` in transcription |
| P3-M5 | State machine (IDLE → TALKING → IDLE) functioning |

### Phase 4: VR SCENE (Day 2 Morning)
**Goal**: Fullscreen VR video plays on cue and returns to AR.

| Milestone | Deliverable |
|-----------|-------------|
| P4-M1 | AVPlayer configured for fullscreen video |
| P4-M2 | Fade-to-black transition implemented |
| P4-M3 | `[VR_SCENE]` marker detection in transcription triggers video |
| P4-M4 | Video plays and returns to AR on completion |
| P4-M5 | Audio pauses/resumes correctly across transition |

### Phase 5: POLISH (Day 2 Afternoon)
**Goal**: Demo-ready. Smooth, impressive, bug-free on stage.

| Milestone | Deliverable |
|-----------|-------------|
| P5-M1 | Spawn animation/VFX for character materialization |
| P5-M2 | Subtitle overlay working |
| P5-M3 | Ambient audio loop playing |
| P5-M4 | UI polish (mic indicator, instructions) |
| P5-M5 | Edge case handling (reconnection, error states) |
| P5-M6 | Full demo rehearsal (match demo script) |
| P5-M7 | Screen mirroring to stage projector tested |

---

## 9. Task Index (Agent-Ready)

Each task is self-contained and can be picked up by an independent agent. Tasks reference their dependencies explicitly.

### 9.0 Implementation Snapshot (7 March 2026 — Evening Update)

This snapshot captures actual repository state after three engineering passes:
- **Pass 1** (Agent 1+2): Track A + B + C code implementation.
- **Pass 2** (Agent 3 / Copilot): Track D + E + F (assets, VR, transitions, multi-animation system).
- **Pass 3** (Agent 3 / Copilot): Bug fixes for device runtime issues (Entity loading, WebSocket timing, audio session).

**All assets are placed. All code is implemented. Simulator builds clean (zero warnings).**

| Task | Status | Notes |
|------|--------|-------|
| T-A01 | **Completed** | `UtamaAI.xcodeproj` created, iOS target added, Info.plist permissions set, folder scaffold created. |
| T-A02 | **Completed** | `AppCoordinator` state machine with VR transitions, audio pipeline management. |
| T-A03 | **Completed** | `ARSceneManager` with plane detection, coaching overlay, auto/tap placement. |
| T-A04 | **Completed** | `CharacterManager` with multi-animation USDZ loading, Entity.load() scene graph, spawn effects. |
| T-A05 | **Completed** | `ContentView` integrates AR + VR layers + fade-to-black transitions + error banner. |
| T-B01 | **Completed** | Gemini WebSocket client with URLSessionWebSocketDelegate for proper connection sequencing. |
| T-B02 | **Completed** | Microphone capture pipeline with 16k mono PCM conversion. |
| T-B03 | **Completed** | Streaming audio playback + amplitude callback. |
| T-B04 | **Completed** | End-to-end voice pipeline in `AppCoordinator` (mic → Gemini → speaker). |
| T-B05 | **Completed** | Character prompt/persona + model/voice config + API key with hardcoded fallback. |
| T-C01 | **Completed** | Amplitude-to-animation sync manager (threshold + debounce). |
| T-C02 | **Completed** | Character spawn/materialization effect (scale-up + SFX). |
| T-C03 | **Completed** | Camera-facing behavior (initial + periodic smooth yaw update). |
| T-D01 | **Completed** | `VRScenePlayer` with AVPlayer, preload, play/stop, completion callback. |
| T-D02 | **Completed** | AR↔VR transitions with fade-to-black overlay, whoosh SFX, state machine. |
| T-E01 | **Completed** | `SubtitleView` with fade-in/out, semi-transparent pill background. |
| T-E02 | **Completed** | `MicIndicatorView` with listening/speaking/idle states + connection indicator. |
| T-E03 | **Completed** | Placement instructions with title and coaching text. |
| T-F01 | **Completed** | Sultan 3D model (CGTrader) → Mixamo rigging → Blender USDZ export → `utama.usdz` (29MB). |
| T-F02 | **Completed** | Lion 3D model (CGTrader, pre-rigged) → Blender USDZ export → `lion.usdz` (14MB). |
| T-F03 | **Completed** | Audio SFX sourced: lion_roar.wav (3.6s), ambient_shore.wav (6m), spawn_shimmer.wav (2.7s), transition_whoosh.wav (5.2s). |
| T-F04 | **Completed** | VR video generated with Veo 3.1 → `lion_encounter_vr.mp4` (35MB, 1080p, 14.6s). |
| T-G01 | **BLOCKED — 3 runtime bugs** | Device build works. Three runtime bugs need fixing before end-to-end test passes. See HANDOFF.md. |
| T-G02 | **Not started** | VR transition test — pending T-G01 bug fixes. |
| T-G03 | **Not started** | Demo rehearsal — pending T-G01 + T-G02. |
| T-G04 | **Not started** | Build for demo device — pending T-G03. |

**Build environment:**
- Xcode 26.3 (Build 17C529), iOS SDK 26.2
- Simulator: iPhone 17 @ iOS 26.3.1 — **BUILD SUCCEEDED** (zero warnings)
- Device: iPhone "Pebble" @ iOS 26.2 — builds and installs, but 3 runtime bugs

**Current blockers (3 runtime bugs on device — see HANDOFF.md for details):**
1. **Sultan model invisible** — `CharacterManager` loads via `Entity.load(contentsOf:)` but Sultan entity may have scene graph issues (possibly the Entity children don't contain visible mesh, or subdirectory path isn't found at runtime on device).
2. **Lion oriented head-down** — Lion model renders but is rotated ~90° with head pointing into the ground. Root transform or axis conversion issue in the USDZ scene graph.
3. **Gemini WebSocket timeout** — "Gemini Live session timed out" error. The `URLSessionWebSocketDelegate.didOpenWithProtocol` callback may not be firing, causing setup message to never send.

**Asset inventory (all present in bundle):**
- `UtamaAI/Assets/Models/`: utama.usdz (29MB), lion.usdz (14MB)
- `UtamaAI/Assets/Animations/`: 8 USDZ files (utama_talking, utama_gesture, utama_bow, utama_dance, lion_roar, lion_walk, lion_run, lion_resting)
- `UtamaAI/Assets/Audio/`: lion_roar.wav, ambient_shore.wav, spawn_shimmer.wav, transition_whoosh.wav
- `UtamaAI/Assets/Video/`: lion_encounter_vr.mp4 (35MB, 1920×1080, H.264, 14.6s)

Detailed bug reproduction, root cause analysis, and fix instructions are in `HANDOFF.md`.

### TRACK A: iOS App Foundation

---

#### T-A01: Create Xcode Project Scaffold
**Priority**: P0 (Critical Path)  
**Dependencies**: None  
**Estimated Effort**: 30 min  
**Description**:  
Create a new Xcode project for the Utama AI app.  

**Deliverables**:
1. New Xcode project named `UtamaAI` with:
   - SwiftUI App lifecycle
   - Target: iOS 17.0+
   - Bundle ID: `com.utama.ai`
   - Device: iPhone only
2. Add required capabilities:
   - Camera Usage Description (Info.plist): "Utama AI needs camera access for AR experience"
   - Microphone Usage Description (Info.plist): "Utama AI needs microphone access for voice interaction"
3. Create folder structure:
   ```
   UtamaAI/
   ├── App/
   │   ├── UtamaAIApp.swift          (App entry point)
   │   └── AppCoordinator.swift       (App state machine)
   ├── AR/
   │   ├── ARSceneManager.swift       (ARView, plane detection, model loading)
   │   ├── ARViewContainer.swift      (UIViewRepresentable wrapper)
   │   └── CharacterManager.swift     (Character placement & animation)
   ├── Voice/
   │   ├── GeminiLiveSession.swift    (WebSocket client)
   │   ├── AudioCaptureEngine.swift   (Mic input → PCM)
   │   └── AudioStreamPlayer.swift    (PCM → speaker output)
   ├── Animation/
   │   └── AnimationSyncManager.swift (Audio amplitude → animation state)
   ├── VR/
   │   └── VRScenePlayer.swift        (AVPlayer fullscreen video)
   ├── UI/
   │   ├── ContentView.swift          (Main view with AR + overlay)
   │   ├── SubtitleView.swift         (Transcript overlay)
   │   └── MicIndicatorView.swift     (Listening state indicator)
   ├── Models/
   │   └── AppState.swift             (Enums, models, state definitions)
   ├── Config/
   │   └── CharacterPrompts.swift     (System prompts, voice configs)
   ├── Assets.xcassets/
   ├── Assets/
   │   ├── Models/                    (USDZ files)
   │   ├── Animations/                (USDZ animation files)
   │   ├── Audio/                     (WAV/MP3 SFX)
   │   └── Video/                     (MP4 VR scene)
   └── Info.plist
   ```
4. Add stub files with `// TODO` comments for each class
5. Verify project builds and runs on simulator (blank screen OK)

---

#### T-A02: Implement App State Machine
**Priority**: P0  
**Dependencies**: T-A01  
**Estimated Effort**: 45 min  
**Description**:  
Implement the `AppCoordinator` as an `ObservableObject` managing the app's state transitions.

**Deliverables**:
1. Define `AppState` enum:
   ```swift
   enum AppState {
       case scanning      // Looking for horizontal plane
       case placing       // Characters materializing
       case conversing    // Main conversation loop
       case vrTransition  // Fading to VR
       case vrPlaying     // VR video playing
       case vrReturn      // Fading back to AR
       case idle          // Post-demo idle
   }
   ```
2. `AppCoordinator` class with:
   - `@Published var appState: AppState = .scanning`
   - `@Published var isListening: Bool = false`
   - `@Published var currentTranscript: String? = nil`
   - `@Published var subtitleText: String? = nil`
   - Methods: `onPlaneDetected()`, `onCharactersPlaced()`, `onVRTrigger()`, `onVRComplete()`, `onError()`
3. State transition logic matching the state diagram in Section 5.2

---

#### T-A03: Implement AR Scene Manager
**Priority**: P0 (Critical Path)  
**Dependencies**: T-A01  
**Estimated Effort**: 2 hours  
**Description**:  
Implement `ARSceneManager` to handle all ARKit/RealityKit operations: camera session, plane detection, model loading, and character anchor placement.

**Deliverables**:
1. `ARSceneManager` class (ObservableObject):
   - `ARView` instance configured for world tracking
   - `ARWorldTrackingConfiguration` with horizontal plane detection + environment texturing
   - `ARCoachingOverlayView` for guided scanning
   - Delegate methods for plane detection (`session(_:didAdd:)`)
2. Character placement:
   - Load USDZ models from app bundle
   - Auto-place on first suitable horizontal plane detected (>0.5m² area)
   - OR raycast-based tap-to-place as fallback
   - Position Sang Nila Utama at center, lion 0.8m to his right
   - Scale characters to realistic proportions (~1.5m height for human)
   - Orient characters to face the camera
3. `ARViewContainer` (UIViewRepresentable) for SwiftUI integration
4. Published properties: `isPlaneDetected`, `areCharactersPlaced`

---

#### T-A04: Implement Character Manager
**Priority**: P0  
**Dependencies**: T-A03  
**Estimated Effort**: 1.5 hours  
**Description**:  
Implement `CharacterManager` to manage multiple AR characters, their animations, and interactions.

**Deliverables**:
1. `CharacterManager` class:
   - Manages two entities: `utamaEntity` and `lionEntity`
   - `loadCharacters()` — loads both USDZ models from bundle
   - `placeCharacters(on anchor: AnchorEntity)` — positions both relative to anchor
   - Animation state tracking per character
2. Animation methods:
   - `playIdleAnimation(for character: Character)` — loop idle
   - `playTalkingAnimation(for character: Character)` — loop talking
   - `playRoarAnimation()` — one-shot lion roar animation
   - `playGestureAnimation(for character: Character)` — one-shot gesture
   - `transitionAnimation(from:to:duration:)` — smooth 0.3s cross-fade between animations
3. Character enum:
   ```swift
   enum Character {
       case utama
       case lion
   }
   ```
4. Handles missing animation gracefully (falls back to idle if animation not found)

---

#### T-A05: Implement Main ContentView
**Priority**: P0  
**Dependencies**: T-A02, T-A03  
**Estimated Effort**: 1 hour  
**Description**:  
Implement the main `ContentView` combining ARView, UI overlays, and VR player.

**Deliverables**:
1. `ContentView`:
   - ZStack with:
     - `ARViewContainer` (full screen, background)
     - `SubtitleView` (bottom area)
     - `MicIndicatorView` (bottom center)
     - Placement instruction (shown during `.scanning` state)
   - State-driven visibility:
     - `.scanning`: Show coaching overlay text
     - `.conversing`: Show mic indicator + subtitle
     - `.vrPlaying`: Hide AR, show VR player fullscreen
2. Connects to `AppCoordinator` environment object
3. Basic structure — actual content implementations in other tasks

---

### TRACK B: Gemini Voice Integration

---

#### T-B01: Implement Gemini WebSocket Client
**Priority**: P0 (Critical Path)  
**Dependencies**: T-A01  
**Estimated Effort**: 3 hours  
**Description**:  
Implement `GeminiLiveSession` — the WebSocket client that connects to Google Gemini Live API, streams audio bidirectionally, and handles the protocol.

**Deliverables**:
1. `GeminiLiveSession` class:
   - Properties:
     - `apiKey: String` (loaded from environment/config)
     - `webSocket: URLSessionWebSocketTask?`
     - `isConnected: Bool`
     - `delegate: GeminiSessionDelegate?`
   - Connection:
     - `connect(persona: CharacterPersona)` — opens WebSocket to `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=API_KEY`
     - Sends setup message with:
       - Model: `models/gemini-2.5-flash-native-audio-preview-12-2025`
       - `response_modalities: ["AUDIO"]`
       - `system_instruction` from `CharacterPrompts.swift`
       - `speech_config` with voice selection
       - `output_audio_transcription: {}` (to get text of responses)
       - `input_audio_transcription: {}` (to get text of user speech)
       - `realtime_input_config` with VAD settings
     - `disconnect()` — cleanly close WebSocket
   - Audio streaming:
     - `sendAudio(_ pcmData: Data)` — wraps PCM in `realtime_input.media_chunks` JSON + base64
     - Continuous receive loop parsing:
       - `serverContent.modelTurn.parts[].inlineData.data` → audio PCM (base64 decode)
       - `serverContent.outputTranscription` → text of model speech
       - `serverContent.inputTranscription` → text of user speech
       - `serverContent.turnComplete` → model finished speaking
       - `setupComplete` → session ready
   - Text input:
     - `sendText(_ text: String)` — for initial greeting trigger, context injection
   - Error handling:
     - Reconnection logic (up to 3 retries)
     - Timeout detection
     - Delegate callbacks for errors
2. `GeminiSessionDelegate` protocol:
   ```swift
   protocol GeminiSessionDelegate: AnyObject {
       func sessionDidConnect()
       func sessionDidDisconnect(error: Error?)
       func didReceiveAudioChunk(_ pcmData: Data)
       func didReceiveTranscription(_ text: String, isUser: Bool)
       func didCompleteTurn()
   }
   ```
3. JSON message construction and parsing (no external JSON library — use Foundation `JSONSerialization`)

---

#### T-B02: Implement Audio Capture Engine
**Priority**: P0 (Critical Path)  
**Dependencies**: T-A01  
**Estimated Effort**: 1.5 hours  
**Description**:  
Implement `AudioCaptureEngine` for capturing microphone audio and providing 16kHz 16-bit mono PCM data.

**Deliverables**:
1. `AudioCaptureEngine` class:
   - Uses `AVAudioEngine` with input node tap
   - Configures audio session:
     - Category: `.playAndRecord`
     - Mode: `.voiceChat`
     - Options: `.defaultToSpeaker`, `.allowBluetooth`
   - Captures audio in 16kHz, 16-bit, mono PCM format
   - If hardware rate differs, uses `AVAudioConverter` to resample to 16kHz
   - Chunk size: ~100ms buffers (1600 samples per chunk at 16kHz)
   - `delegate: AudioCaptureDelegate?` for delivering PCM chunks
   - `startCapture()` / `stopCapture()` methods
   - Handles audio session interruptions (phone calls, etc.)
2. `AudioCaptureDelegate` protocol:
   ```swift
   protocol AudioCaptureDelegate: AnyObject {
       func didCapturePCMData(_ data: Data)
   }
   ```

---

#### T-B03: Implement Audio Stream Player
**Priority**: P0 (Critical Path)  
**Dependencies**: T-A01  
**Estimated Effort**: 1.5 hours  
**Description**:  
Implement `AudioStreamPlayer` for playing streamed 24kHz PCM audio from Gemini responses.

**Deliverables**:
1. `AudioStreamPlayer` class:
   - Uses `AVAudioEngine` + `AVAudioPlayerNode`
   - Configures for 24kHz, 16-bit, mono PCM playback
   - `enqueueAudioChunk(_ pcmData: Data)` — creates `AVAudioPCMBuffer` and schedules on player node
   - `stop()` — stops playback and clears buffer
   - `isPlaying: Bool` — whether audio is currently playing
   - Calculates RMS amplitude per chunk for animation sync:
     - `var currentAmplitude: Float` (updated per chunk)
     - Callback: `onAmplitudeUpdate: ((Float) -> Void)?`
   - Handles audio format conversion if needed
   - Detects playback completion (all buffers consumed)
   - Callback: `onPlaybackComplete: (() -> Void)?`
2. Thread-safe buffer queue (audio processing on background thread, callbacks on main)

---

#### T-B04: Integrate Voice Pipeline End-to-End
**Priority**: P0 (Critical Path)  
**Dependencies**: T-B01, T-B02, T-B03, T-A02  
**Estimated Effort**: 2 hours  
**Description**:  
Wire together the complete voice pipeline: mic → Gemini → speaker, managed by `AppCoordinator`.

**Deliverables**:
1. In `AppCoordinator`:
   - Initialize `GeminiLiveSession`, `AudioCaptureEngine`, `AudioStreamPlayer`
   - Implement `GeminiSessionDelegate`:
     - `didReceiveAudioChunk` → forward to `AudioStreamPlayer`
     - `didReceiveTranscription` → update `subtitleText`
     - `didCompleteTurn` → stop speaking state
   - Implement `AudioCaptureDelegate`:
     - `didCapturePCMData` → forward to `GeminiLiveSession.sendAudio()`
   - `startConversation()`:
     - Connect Gemini session
     - Start audio capture
     - Send initial greeting trigger text: "A new traveler has arrived. Greet them."
   - Handle `[LION_ROAR]` marker: parse transcription, play roar SFX, trigger lion animation
   - Handle `[VR_SCENE]` marker: transition to VR state
2. Audio session management:
   - Configure `AVAudioSession` for simultaneous record + playback
   - Handle interruptions gracefully
3. Test: user speaks → Gemini responds in character → audio plays → repeat

---

#### T-B05: Configure Character Personas
**Priority**: P1  
**Dependencies**: T-B01  
**Estimated Effort**: 30 min  
**Description**:  
Create the `CharacterPrompts.swift` configuration file with all persona definitions.

**Deliverables**:
1. `CharacterPrompts.swift` with:
   - `struct CharacterPersona`:
     ```swift
     struct CharacterPersona {
         let name: String
         let systemPrompt: String
         let voiceName: String
         let modelId: String
     }
     ```
   - `static let sangNilaUtama` — full system prompt from Section 7.1
   - `static let voiceOptions` — list of voice candidates to test
   - `static let modelId = "models/gemini-2.5-flash-native-audio-preview-12-2025"`
2. API key loading from environment or bundled config:
   ```swift
   static var apiKey: String {
       ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? ""
   }
   ```

---

### TRACK C: Animation & Visual Effects

---

#### T-C01: Implement Animation Sync Manager
**Priority**: P1  
**Dependencies**: T-A04, T-B03  
**Estimated Effort**: 1.5 hours  
**Description**:  
Implement `AnimationSyncManager` that bridges audio amplitude data to character animation states.

**Deliverables**:
1. `AnimationSyncManager` class:
   - Receives amplitude updates from `AudioStreamPlayer`
   - Maintains state machine per character:
     ```
     IDLE ←→ TALKING
     IDLE → ROARING (lion only)
     ROARING → IDLE
     ```
   - Thresholds:
     - `talkingThreshold: Float = 0.05` (amplitude above → talking)
     - `idleThreshold: Float = 0.02` (amplitude below → idle)
     - Debounce: 200ms before switching to idle (prevents flickering)
   - Calls `CharacterManager` animation methods
   - `func updateFromAmplitude(_ amplitude: Float, for character: Character)`
   - `func triggerLionRoar()` — plays roar animation + SFX
   - Uses `Timer` or `DisplayLink` for regular polling if needed

---

#### T-C02: Implement Character Spawn Effect
**Priority**: P2  
**Dependencies**: T-A04  
**Estimated Effort**: 1 hour  
**Description**:  
Create a visual spawn/materialization effect when characters first appear.

**Deliverables**:
1. Spawn effect options (pick one):
   - **Scale-up**: Character scales from 0 to 1.0 over 1 second with ease-out
   - **Shimmer/dissolve**: Use RealityKit's `SimpleMaterial` with animated opacity
   - **Particle burst**: Use `ParticleEmitterComponent` for golden sparkles on spawn
2. Implementation in `CharacterManager`:
   - `spawnCharacter(_ character: Character, on anchor: AnchorEntity)`
   - Character starts invisible (scale 0 or opacity 0)
   - Animates to visible over 1–1.5 seconds
   - Plays `spawn_shimmer.wav` SFX
   - Utama spawns first, lion 0.5 seconds later
3. Triggers `AppCoordinator.onCharactersPlaced()` when complete

---

#### T-C03: Implement Character Camera Facing
**Priority**: P1  
**Dependencies**: T-A03, T-A04  
**Estimated Effort**: 45 min  
**Description**:  
Make characters orient toward the camera/user.

**Deliverables**:
1. On initial placement, characters face the camera:
   - Get camera transform from `arView.session.currentFrame?.camera.transform`
   - Calculate yaw angle from camera position to character position
   - Set character `orientation` to face camera
2. Optional: gentle look-at behavior during conversation:
   - Update character yaw toward camera every ~1 second (smoothly interpolate)
   - Only affect Y-axis rotation (not tilt)

---

### TRACK D: VR Scene & Transitions

---

#### T-D01: Implement VR Scene Player
**Priority**: P1  
**Dependencies**: T-A01  
**Estimated Effort**: 1.5 hours  
**Description**:  
Implement `VRScenePlayer` for fullscreen video playback of the pre-generated Veo scene.

**Deliverables**:
1. `VRScenePlayer` class (ObservableObject):
   - Uses `AVPlayer` to play bundled MP4 video
   - `preload()` — loads video into player early for instant playback
   - `play()` — starts fullscreen playback
   - `stop()` — stops and resets
   - `isPlaying: Bool`
   - `onComplete: (() -> Void)?` callback when video ends
   - Handles `AVPlayerItem.didPlayToEndTime` notification
2. SwiftUI view:
   - `VRSceneView` — fullscreen video layer
   - Covers entire screen (hides AR)
   - No controls visible (auto-play, single viewing)
3. Video loaded from `Assets/Video/lion_encounter_vr.mp4`

---

#### T-D02: Implement AR ↔ VR Transitions
**Priority**: P1  
**Dependencies**: T-D01, T-A02  
**Estimated Effort**: 1 hour  
**Description**:  
Implement smooth visual transitions between AR and VR modes.

**Deliverables**:
1. AR → VR transition:
   - Detect `[VR_SCENE]` marker in Gemini transcription output
   - Pause Gemini audio / disconnect temporarily
   - Fade screen to black over 1 second (animated black overlay)
   - Play transition_whoosh.wav
   - Switch view to `VRSceneView`
   - Fade in from black over 0.5 seconds
   - Video plays
2. VR → AR transition:
   - Video ends → fade to black over 0.5 seconds
   - Switch view back to `ARViewContainer`
   - Fade in from black over 1 second
   - Resume/reconnect Gemini session
   - Send context message: "You just showed the traveler the vision of your lion encounter. Continue the conversation."
   - Utama speaks a follow-up line
3. State machine transitions:
   - `.conversing` → `.vrTransition` → `.vrPlaying` → `.vrReturn` → `.conversing`

---

### TRACK E: UI & Overlay

---

#### T-E01: Implement Subtitle Overlay
**Priority**: P2  
**Dependencies**: T-A05, T-B04  
**Estimated Effort**: 45 min  
**Description**:  
Display real-time subtitles of what Sang Nila Utama is saying.

**Deliverables**:
1. `SubtitleView`:
   - Semi-transparent dark background pill at bottom of screen
   - White text, 16pt, max 2 lines
   - Shows `AppCoordinator.subtitleText`
   - Fades in when text appears, fades out 2 seconds after turn completes
   - Auto-scrolls / truncates long text
   - Animation: text slides up gently as new words arrive
2. Positioned above the mic indicator, below center of screen
3. Hidden when `subtitleText` is nil or in `.scanning` / `.vrPlaying` states

---

#### T-E02: Implement Microphone Indicator
**Priority**: P2  
**Dependencies**: T-A05, T-A02  
**Estimated Effort**: 30 min  
**Description**:  
Visual indicator showing when the app is listening vs. when Gemini is speaking.

**Deliverables**:
1. `MicIndicatorView`:
   - Circular button at bottom-center
   - States:
     - **Listening** (mic active): Pulsing blue circle with mic icon, animated audio waves
     - **AI Speaking**: Glowing gold ring, speaker icon
     - **Idle**: Static gray circle with mic icon
   - Tapping toggles listen mode (optional — VAD handles this automatically)
2. Animated transitions between states (0.3s spring animation)
3. Shows connection status: red dot if WebSocket disconnected

---

#### T-E03: Implement Placement Instructions
**Priority**: P2  
**Dependencies**: T-A05  
**Estimated Effort**: 20 min  
**Description**:  
On-screen instructions during the scanning phase.

**Deliverables**:
1. During `.scanning` state, show centered text:
   - "Point your camera at a flat surface" (with subtle animation)
   - `ARCoachingOverlayView` handles the main guidance
   - Additional branding: "Utama AI" title at top, small logo
2. Auto-hides when plane is detected and characters are placed
3. Subtle fade-out animation

---

### TRACK F: Asset Preparation

---

#### T-F01: Source & Convert Sang Nila Utama 3D Model
**Priority**: P0 (Blocker for Track A)  
**Dependencies**: None  
**Estimated Effort**: 2–3 hours  
**Description**:  
Find, purchase, and convert a suitable 3D character model for Sang Nila Utama.

**Deliverables**:
1. Search CGTrader, Sketchfab, TurboSquid for:
   - "Southeast Asian warrior/prince rigged"
   - "Ancient king character rigged animated"
   - "Malay warrior 3D model"
   - Requirements: humanoid, rigged, under $60, FBX or GLB format
2. If no perfect match: Get a generic warrior/prince model and note costume limitations
3. Upload to Mixamo → auto-rig if needed → apply animations:
   - `Idle` (happy idle or breathing idle) — looping
   - `Talking` (Talking or Talking_1) — looping
   - `Pointing` (arm spread or pointing) — one-shot
   - `Bow` (bow or head nod) — one-shot
4. Download each as FBX (with skin, 30 FPS)
5. Convert each to USDZ using Reality Converter
6. Verify in Xcode Quick Look / Reality Composer Pro:
   - Materials render correctly
   - Animations play
   - Scale is reasonable
7. Place final files in `Assets/Models/` and `Assets/Animations/`

---

#### T-F02: Source & Convert Lion 3D Model
**Priority**: P0 (Blocker for Track A)  
**Dependencies**: None  
**Estimated Effort**: 1.5–2 hours  
**Description**:  
Find and convert a suitable animated lion 3D model.

**Deliverables**:
1. Search Sketchfab, CGTrader for:
   - "lion animated" — must include idle + roar animations
   - Prefer models with USDZ or GLB download
   - Budget: free – $30
2. The model MUST come pre-animated (Mixamo doesn't support animals):
   - Minimum: idle (standing/breathing) + roar animation
   - Nice-to-have: walk cycle
3. Convert to USDZ via Reality Converter or Blender
4. Verify animations work in Quick Look
5. If no animations: use a static lion pose and only play roar SFX (no animation)
6. Place final file in `Assets/Models/lion.usdz`

---

#### T-F03: Source Audio SFX Assets
**Priority**: P1  
**Dependencies**: None  
**Estimated Effort**: 30 min  
**Description**:  
Download all needed sound effect audio files.

**Deliverables**:
1. From freesound.org (CC0/CC-BY license):
   - **Lion roar**: Search "lion roar" — pick a dramatic, clear roar (3–5 seconds)
   - **Ambient shore**: Search "tropical beach ambience" — loopable, 30+ seconds
   - **Spawn shimmer**: Search "magic shimmer" or "spell cast" — short sparkle sound
   - **Transition whoosh**: Search "cinematic whoosh" — 1–2 seconds
2. Download as WAV (or MP3 and convert to WAV)
3. Normalize audio levels
4. Place in `Assets/Audio/`:
   - `lion_roar.wav`
   - `ambient_shore.wav`
   - `spawn_shimmer.wav`
   - `transition_whoosh.wav`

---

#### T-F04: Generate VR Scene with Veo 3.1
**Priority**: P1  
**Dependencies**: None (requires Google API key)  
**Estimated Effort**: 1–2 hours (includes generation wait time)  
**Description**:  
Generate the cinematic VR scene video using Google Veo 3.1.

**Deliverables**:
1. Using Google AI Studio or Veo API, generate Scene 1:
   ```
   Prompt: "Cinematic wide shot of an ancient Southeast Asian prince in golden 
   royal Malay attire standing on a lush tropical beach shore in the 13th century. 
   Tall palm trees sway in the warm wind. He gazes in awe at the dense jungle edge. 
   A powerful, majestic lion slowly emerges from the treeline, making eye contact 
   with the prince. The prince whispers in awe, 'Singapura.' The lion roars 
   magnificently. Golden hour sunset lighting, warm cinematic color grading, 
   epic historical film style. Dramatic orchestral music."
   
   Config: 8 seconds, 1080p, 16:9
   ```
2. Generate 3–5 variations, select the best one
3. Optionally generate an extension (Scene 2) for a 16-second total:
   ```
   "Continue. The prince approaches the lion slowly. The lion stands regally. 
   They face each other on the shore as the sun sets behind them. The prince 
   raises his hand toward the island. Epic and emotional."
   ```
4. If extending, use FFmpeg to concatenate: `ffmpeg -i scene1.mp4 -i scene2.mp4 -filter_complex concat=n=2 lion_encounter_vr.mp4`
5. Place final video in `Assets/Video/lion_encounter_vr.mp4`
6. Also export a short 3-second teaser version (optional)

---

### TRACK G: Integration & Testing

---

#### T-G01: End-to-End Integration Test
**Priority**: P0  
**Dependencies**: T-B04, T-A04, T-C01  
**Estimated Effort**: 2 hours  
**Description**:  
Wire all systems together and test on a real iPhone.

**Deliverables**:
1. Full flow test on device:
   - App opens → camera shows → plane detected → characters appear
   - Gemini connects → proactive greeting plays → character animates
   - User speaks → Gemini responds → audio plays → animation syncs
   - Lion roar triggers correctly
2. Performance check:
   - AR rendering stays at 60fps
   - Audio latency is under 1 second
   - No audio glitches or pops
   - WebSocket stays connected for 5+ minutes
3. Fix any integration bugs found
4. Document any issues for Phase 5 polish

---

#### T-G02: VR Transition Integration Test
**Priority**: P1  
**Dependencies**: T-D02, T-G01  
**Estimated Effort**: 1 hour  
**Description**:  
Test the complete AR → VR → AR transition flow.

**Deliverables**:
1. Test flow:
   - During conversation, user asks to see the story
   - Gemini responds with `[VR_SCENE]` marker
   - Screen fades to black smoothly
   - Video plays fullscreen with audio
   - Video ends, returns to AR
   - Conversation resumes naturally
2. Verify:
   - Audio doesn't overlap (Gemini audio stops before video audio)
   - AR session survives the transition (characters still present)
   - No memory spikes or crashes

---

#### T-G03: Demo Rehearsal & Polish
**Priority**: P1  
**Dependencies**: T-G01, T-G02  
**Estimated Effort**: 2 hours  
**Description**:  
Full dress rehearsal matching the demo script from Section 2.1.

**Deliverables**:
1. Run through demo script 3 times end-to-end
2. Test screen mirroring to external display (AirPlay/cable)
3. Verify audio is loud enough through iPhone speakers (or prepare Bluetooth speaker)
4. Prepare fallback responses:
   - If Gemini is slow: pre-record audio for greeting (play from file as fallback)
   - If WebSocket drops: reconnection logic works within 3 seconds
5. Time the demo: must fit in 3–5 minutes
6. Create a "safe" conversation flow list (suggested questions that work well)
7. Final bug fixes and UI tweaks

---

#### T-G04: Build & Archive for Demo Device
**Priority**: P1  
**Dependencies**: T-G03  
**Estimated Effort**: 30 min  
**Description**:  
Create a stable build installed on the demo iPhone.

**Deliverables**:
1. Set app to Release build configuration
2. Ensure API key is embedded (not requiring env var at runtime)
3. Build and install on target iPhone via Xcode
4. Verify app launches correctly from home screen
5. Disable any debug UI / console logging
6. Test that app works without Xcode connected (standalone)

---

## 10. File & Folder Structure

```
UTAMA_AI/
├── BRD.md                          ← This document
├── GEMINI.md                       ← Gemini research notes
├── RESEARCH.md                     ← Detailed technology research
├── .env                            ← GOOGLE_API_KEY=xxx
├── .gitignore
│
├── UtamaAI/                        ← Xcode project root
│   ├── UtamaAI.xcodeproj/
│   ├── UtamaAI/
│   │   ├── App/
│   │   │   ├── UtamaAIApp.swift
│   │   │   └── AppCoordinator.swift
│   │   ├── AR/
│   │   │   ├── ARSceneManager.swift
│   │   │   ├── ARViewContainer.swift
│   │   │   └── CharacterManager.swift
│   │   ├── Voice/
│   │   │   ├── GeminiLiveSession.swift
│   │   │   ├── AudioCaptureEngine.swift
│   │   │   └── AudioStreamPlayer.swift
│   │   ├── Animation/
│   │   │   └── AnimationSyncManager.swift
│   │   ├── VR/
│   │   │   └── VRScenePlayer.swift
│   │   ├── UI/
│   │   │   ├── ContentView.swift
│   │   │   ├── SubtitleView.swift
│   │   │   └── MicIndicatorView.swift
│   │   ├── Models/
│   │   │   └── AppState.swift
│   │   ├── Config/
│   │   │   └── CharacterPrompts.swift
│   │   ├── Assets.xcassets/
│   │   │   └── AppIcon.appiconset/
│   │   ├── Assets/
│   │   │   ├── Models/
│   │   │   │   ├── sang_nila_utama.usdz
│   │   │   │   └── lion.usdz
│   │   │   ├── Animations/
│   │   │   │   ├── utama_idle.usdz
│   │   │   │   ├── utama_talking.usdz
│   │   │   │   ├── utama_gesture.usdz
│   │   │   │   └── utama_bow.usdz
│   │   │   ├── Audio/
│   │   │   │   ├── lion_roar.wav
│   │   │   │   ├── ambient_shore.wav
│   │   │   │   ├── spawn_shimmer.wav
│   │   │   │   └── transition_whoosh.wav
│   │   │   └── Video/
│   │   │       └── lion_encounter_vr.mp4
│   │   └── Info.plist
│   └── UtamaAITests/
│
├── Scripts/
│   ├── generate_veo_scene.py       ← Script to generate Veo 3.1 video
│   └── test_gemini_live.py         ← Script to test Gemini Live API
│
└── Docs/
    └── demo_script.md              ← Stage demo script with timing
```

---

## 11. API Configuration Reference

### 11.1 Gemini Live API Setup Message

```json
{
  "setup": {
    "model": "models/gemini-2.5-flash-native-audio-preview-12-2025",
    "generation_config": {
      "response_modalities": ["AUDIO"],
      "speech_config": {
        "voice_config": {
          "prebuilt_voice_config": {
            "voice_name": "Charon"
          }
        }
      },
      "temperature": 0.8
    },
    "system_instruction": {
      "parts": [
        {
          "text": "<FULL SYSTEM PROMPT FROM SECTION 7.1>"
        }
      ]
    },
    "tools": [],
    "realtime_input_config": {
      "automatic_activity_detection": {
        "disabled": false,
        "start_of_speech_sensitivity": "START_SENSITIVITY_LOW",
        "end_of_speech_sensitivity": "END_SENSITIVITY_LOW",
        "silence_duration_ms": 300
      }
    },
    "output_audio_transcription": {},
    "input_audio_transcription": {}
  }
}
```

### 11.2 Audio Streaming Message

```json
{
  "realtime_input": {
    "media_chunks": [
      {
        "mime_type": "audio/pcm;rate=16000",
        "data": "<BASE64_ENCODED_PCM_BYTES>"
      }
    ]
  }
}
```

### 11.3 Text Input Message (for greeting trigger)

```json
{
  "client_content": {
    "turns": [
      {
        "role": "user",
        "parts": [{ "text": "A new traveler has just arrived. Greet them warmly." }]
      }
    ],
    "turn_complete": true
  }
}
```

### 11.4 Expected Server Response Structure

```json
{
  "serverContent": {
    "modelTurn": {
      "parts": [
        {
          "inlineData": {
            "mimeType": "audio/pcm;rate=24000",
            "data": "<BASE64_PCM_BYTES>"
          }
        }
      ]
    },
    "outputTranscription": {
      "parts": [{ "text": "Greetings, traveler. I am Sang Nila Utama..." }]
    },
    "turnComplete": true
  }
}
```

### 11.5 Veo 3.1 Generation Config

```python
from google import genai
from google.genai import types

client = genai.Client()  # GOOGLE_API_KEY env var

operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    prompt="<SCENE PROMPT FROM SECTION 6.3>",
    config=types.GenerateVideosConfig(
        aspect_ratio="16:9",
        resolution="1080p",
        number_of_videos=1,
        duration_seconds=8,
        person_generation="allow_all",
    ),
)

# Poll until done
import time
while not operation.done:
    time.sleep(10)
    operation = client.operations.get(operation)

video = operation.response.generated_videos[0]
video.video.save("lion_encounter_vr.mp4")
```

### 11.6 WebSocket URL

```
wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=YOUR_API_KEY
```

### 11.7 Environment Variables

```bash
# .env
GOOGLE_API_KEY=your_google_api_key_here
```

---

## 12. Demo Script & Stage Plan

### 12.1 Suggested Questions for Demo

These questions are tested to produce good responses from the Sang Nila Utama persona:

| # | Question | Expected Response Theme |
|---|----------|----------------------|
| 1 | *(proactive greeting)* | Introduction, welcome, setting the scene |
| 2 | "What was it like when you first saw the lion?" | Vivid storytelling, emotion, awe |
| 3 | "Were you afraid?" | Bravery, faith, destiny |
| 4 | "What about you, lion?" | Lion roars, Utama comments humorously |
| 5 | "Tell me about Srivijaya" | Cultural history, trade, maritime empire |
| 6 | "What does Singapura mean?" | Etymology, naming story |
| 7 | "Can you show me what happened that day?" | VR transition trigger |
| 8 | *(after VR returns)* "That was incredible." | Reflective, emotional follow-up |

### 12.2 Timing Plan

| Time | Action | Duration |
|------|--------|----------|
| 0:00 | Open app, point at stage floor | 10s |
| 0:10 | Characters appear (spawn animation) | 5s |
| 0:15 | Proactive greeting plays | 20s |
| 0:35 | Q1: "What was it like seeing the lion?" | 5s speak + 20s response |
| 1:00 | Q2: "Were you afraid?" | 5s + 15s |
| 1:20 | Q3: "What about you, lion?" | 5s + 10s (roar + comment) |
| 1:35 | Q4: Brief cultural question | 5s + 20s |
| 2:00 | "Can you show me?" → VR transition | 10s transition |
| 2:10 | VR video plays | 16s |
| 2:26 | Return to AR | 5s |
| 2:31 | Brief closing exchange | 20s |
| 2:51 | End demo | — |
| **Total** | | **~3 minutes** |

### 12.3 Stage Setup

- iPhone connected to projector via AirPlay or Lightning-to-HDMI
- Stage has a flat floor area (for plane detection)
- Room lighting should be moderate (not too dark for ARKit tracking)
- Bluetooth speaker nearby if iPhone speaker is too quiet
- Backup: pre-recorded video of the demo if live demo fails

---

## 13. Risk Register

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|-----------|------------|
| R1 | Gemini WebSocket disconnects during demo | High | Medium | Auto-reconnect logic (3 retries). Pre-recorded greeting audio as fallback. |
| R2 | High latency on Gemini response (>2s) | Medium | Medium | Use native audio model (fastest). Fallback: pre-recorded responses. Transition animation masks small delays. |
| R3 | Stage WiFi unreliable | Critical | Medium | Use personal hotspot (4G/5G) as primary. Test beforehand. |
| R4 | 3D model doesn't look good enough | Medium | Low | Source 2-3 backup models beforehand. Stylized/low-poly is acceptable. |
| R5 | ARKit can't detect plane on dark stage | Medium | Medium | Test in venue beforehand. Carry a light-colored mat or paper to place on floor. AR coaching overlay guides user. |
| R6 | Audio feedback loop (speaker→mic) | High | Medium | VAD handles this. Lower speaker volume. Use earbuds for audience demo. |
| R7 | Veo-generated video quality insufficient | Low | Low | Generate 5+ variations and pick best. Quality is generally high. |
| R8 | USDZ conversion breaks materials | Medium | Medium | Test all conversions early. Have Blender as fallback tool. |
| R9 | Memory pressure / crash from large assets | Medium | Low | Keep models under 50k poly. Compress textures. Test on target device. |
| R10 | Gemini refuses or breaks character | Low | Low | Extensive system prompt testing. Temperature 0.8 for creativity. |

---

## 14. Acceptance Criteria

### MVP Definition of Done

- [ ] **AC-01**: App launches and shows camera feed with AR coaching overlay
- [ ] **AC-02**: Horizontal plane detected and both characters (Utama + Lion) appear within 10 seconds
- [ ] **AC-03**: Characters have idle animations playing (breathing/movement)
- [ ] **AC-04**: Sang Nila Utama greets the user proactively upon placement
- [ ] **AC-05**: User can speak and receive voiced response from Sang Nila Utama within 2 seconds
- [ ] **AC-06**: Sang Nila Utama's talking animation plays during speech
- [ ] **AC-07**: At least 3 back-and-forth conversation exchanges work reliably
- [ ] **AC-08**: Lion roars when addressed (audio + animation if available)
- [ ] **AC-09**: VR scene triggers on conversation cue and plays fullscreen video
- [ ] **AC-10**: VR scene returns to AR mode upon completion
- [ ] **AC-11**: App runs stable for 5 minutes without crash
- [ ] **AC-12**: Demo completes within 3–5 minutes following the demo script

### Stretch Goals

- [ ] **SG-01**: Subtitle overlay shows real-time transcription
- [ ] **SG-02**: Jaw/mouth animation synced to audio amplitude
- [ ] **SG-03**: Spatial audio (sound appears to come from character position)
- [ ] **SG-04**: Character spawn particle effects
- [ ] **SG-05**: Ambient audio loop (shore/jungle sounds)
- [ ] **SG-06**: Microphone indicator with animated audio waves

---

## Task Dependency Graph

```
PREP (Parallel — No Dependencies)
├── T-F01: Source Utama 3D Model ─────────────────────┐
├── T-F02: Source Lion 3D Model ──────────────────────┐│
├── T-F03: Source Audio SFX ──────────────────────────┐││
├── T-F04: Generate Veo VR Scene ─────────────────────┐│││
│                                                      ││││
FOUNDATION                                             ││││
├── T-A01: Xcode Project Scaffold ◄────────────────────┘│││
│   ├── T-A02: App State Machine                        │││
│   ├── T-A03: AR Scene Manager ◄───────(needs models)──┘││
│   │   └── T-A04: Character Manager ◄──(needs models)───┘│
│   │       └── T-C02: Spawn Effect                       │
│   │       └── T-C03: Camera Facing                      │
│   └── T-A05: Main ContentView (needs T-A02, T-A03)     │
│                                                          │
VOICE (Parallel with AR after T-A01)                      │
├── T-B01: WebSocket Client                               │
│   └── T-B05: Character Personas                         │
├── T-B02: Audio Capture Engine                           │
├── T-B03: Audio Stream Player                            │
└── T-B04: Voice Pipeline Integration ◄──(T-B01+B02+B03) │
    └── T-C01: Animation Sync ◄──(needs T-A04, T-B03)    │
                                                           │
VR                                                         │
├── T-D01: VR Scene Player ◄─────────(needs T-F04 video)──┘
└── T-D02: AR↔VR Transitions ◄───────(T-D01 + T-A02)

UI (Parallel after T-A05)
├── T-E01: Subtitle Overlay
├── T-E02: Mic Indicator
└── T-E03: Placement Instructions

INTEGRATION (Everything converges)
├── T-G01: End-to-End Test ◄──────────(T-B04 + T-A04 + T-C01)
├── T-G02: VR Transition Test ◄──────(T-D02 + T-G01)
├── T-G03: Demo Rehearsal ◄──────────(T-G01 + T-G02)
└── T-G04: Build for Demo ◄──────────(T-G03)
```

---

## Parallel Work Assignment Guide

**For 3 agents working simultaneously:**

| Agent | Track | Tasks (in order) |
|-------|-------|-------------------|
| **Agent 1 — iOS/AR** | A + C | T-A01 → T-A02 → T-A03 → T-A04 → T-A05 → T-C03 → T-C02 → T-C01 |
| **Agent 2 — Voice/AI** | B | T-B01 → T-B02 → T-B03 → T-B04 → T-B05 |
| **Agent 3 — Assets/VR/UI** | F + D + E | T-F01 ∥ T-F02 ∥ T-F03 ∥ T-F04 → T-D01 → T-D02 → T-E01 → T-E02 → T-E03 |

**Integration sync point**: After Agent 1 completes T-A04 and Agent 2 completes T-B04, all three collaborate on T-G01 → T-G02 → T-G03 → T-G04.

---

*End of BRD — Document generated for Utama AI Hackathon MVP*
