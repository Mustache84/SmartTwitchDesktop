# AI Agent Context File

> **Last Updated:** February 4, 2026  
> **Current Phase:** 1.8 (Full Player Controls + DVR)  
> **For detailed task breakdown, see:** `FLUTTER_MIGRATION_PLAN.md`

---

## Project Overview

**SmartTwitchDesktop** is a native Flutter desktop app (macOS/Windows/Linux) for watching Twitch streams. It's a migration from the original SmartTwitchTV Android/web app, keeping the JS codebase in `app/` as reference only.

### Tech Stack
| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.38.9 (desktop) |
| Video Engine | `fvp` v0.35.2 (MDK-based, hardware-accelerated) |
| State Management | `flutter_riverpod` v3.1.0 (Notifier pattern) |
| HTTP | `dio` v5.7.0 |
| Twitch API | GraphQL via `gql.twitch.tv/gql` |

### Project Structure
```
SmartTwitchDesktop/
├── smart_twitch_flutter/     # Flutter app (active development)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # Data models
│   │   ├── screens/          # Full-page screens
│   │   ├── services/         # API, video, auth services
│   │   ├── state/            # Riverpod providers
│   │   ├── utils/            # Helpers, config
│   │   └── widgets/          # Reusable UI components
│   └── pubspec.yaml
├── app/                      # Original JS codebase (REFERENCE ONLY - delete after Phase 2)
├── FLUTTER_MIGRATION_PLAN.md # Detailed roadmap with task lists
└── AI_CONTEXT.md             # This file
```

---

## What's Complete

### ✅ Video Playback (Phase 1)
- Hardware-accelerated HLS via MDK/fvp
- `TwitchApiService` - GraphQL token fetching
- `HlsUrlBuilder` - Twitch manifest URL construction (now with `av1,h265,h264` codecs for 1440p)
- Offline channel detection

### ✅ Multi-Stream (Phase 3 Partial)
- 4-slot management with Riverpod
- 2x2 grid layout with drag-drop reordering
- Audio focus switching (one stream audible at a time)
- `VideoControllerManager` singleton for controller persistence

### ✅ Home Screen
- Featured streams with thumbnails
- Categories/games browsing
- **Stream preview on hover** with instant playback
- `PreviewPlayerManager` - pre-initializes all 10 controllers
- Collapsible sidebar with login/logout

### ✅ OAuth (Phase 1.5)
- `SecureTokenStorage` - Keychain/Credential Manager/libsecret storage
- `TwitchAuthService` - Device Code Grant flow with polling
- `TokenManager` - Auto-refresh tokens before expiry
- `AuthProvider` - Riverpod state for authentication
- `LoginScreen` - Device code UI with copy-to-clipboard
- Sidebar shows login status with logout button
- `TwitchApiService` uses auth tokens when available

### ✅ Player Controls Foundation (Phase 1.6)
- `shared_preferences` for persistent settings
- `SettingsService` - per-channel quality, latency, volume settings
- `HlsManifestService` - parses HLS manifests for quality enumeration
- `PlayerControlsProvider` - Riverpod state for player controls
- Enabled 1440p/4K codecs (`av1,h265,h264`)

### ✅ Low Latency & Quality Selection (Phase 1.7)
- `LowLatencyService` - buffer control, latency presets (0.5s - 10s)
- `QualitySelector` widget - dropdown from HLS manifest
- `LatencySlider` widget - compact and full modes
- `TwitchPlayerController` wrapper for runtime player control
- **Working keyboard shortcuts:** Space (play/pause), M (mute), L (low latency), H (hide UI), ↑↓ (volume)
- Player controls overlay with play/pause, mute, volume slider

---

## Current Work: Phase 1.8 - Full Player Controls + DVR

Finalizing player controls and adding DVR/rewind support.

### Phase 1.8 Task List
1. [ ] Auto-hide controls overlay after 3s inactivity
2. [ ] Fullscreen toggle (F key)
3. [ ] Stats overlay (Ctrl+D)
4. [ ] "Sync All Streams" for multi-stream
5. [ ] DVR/Rewind (check subscription via OAuth)
6. [ ] Quality selection that actually switches the stream (currently saves preference only)

---

## Upcoming Phases

### Phase 1.8: Full Player Controls + DVR (Current)
- Auto-hide controls overlay after 3s inactivity
- Fullscreen toggle, stats overlay
- "Sync All Streams" for multi-stream
- DVR/Rewind for subscribers (check via OAuth)
- Wire up quality selection to actually switch streams

### Phase 2: Chat System
- `TwitchIrcClient` with WebSocket
- IRC message parser (port from `app/thirdparty/irc-message.js`)
- `EmoteService` (BTTV/FFZ/7TV)
- Chat overlay widget
- Wire up search functionality

---

## Key Files to Know

| File | Purpose |
|------|---------|
| `lib/services/twitch_api_service.dart` | GraphQL token fetching, API calls |
| `lib/services/twitch_auth_service.dart` | OAuth Device Code Grant flow |
| `lib/services/settings_service.dart` | Persistent settings via shared_preferences |
| `lib/services/low_latency_service.dart` | Buffer control, latency presets |
| `lib/services/hls_manifest_service.dart` | Parses HLS manifests for quality options |
| `lib/utils/hls_url_builder.dart` | Constructs Twitch HLS manifest URLs |
| `lib/services/preview_player_manager.dart` | Pre-initializes video controllers for hover preview |
| `lib/state/multi_stream_notifier.dart` | Riverpod state for 4-slot multi-stream |
| `lib/state/auth_provider.dart` | Riverpod state for authentication |
| `lib/widgets/video_widget.dart` | Video player with TwitchPlayerController |
| `lib/widgets/quality_selector.dart` | Quality dropdown from HLS manifest |
| `lib/widgets/latency_slider.dart` | Latency control widgets |
| `lib/utils/ui_config.dart` | Tunable UIUX constants (expose in Settings later) |

---

## API Client IDs

| Purpose | Client ID |
|---------|-----------|
| **OAuth (User Auth)** | `vrhsf9gxj2y4jntunres6mzber1fg1` |
| Anonymous Tokens (Primary) | `kd1unb4b3q4t58fwlpcbzcbnm76a8fp` |
| Anonymous Tokens (Fallback 1) | `ue666qo983tsx6so1t0vnawi233wa` |
| Anonymous Tokens (Fallback 2) | `kimne78kx3ncx6brgo4mv6wki5h1ko` |

---

## Design Principles

1. **UIUX Configurability:** All timing/animation values should be tunable via `ui_config.dart` and eventually exposed in Settings.

2. **Let MDK Handle It:** For codec detection, fallback, etc. - request all codecs, MDK picks the best available.

3. **Simple Settings Storage:** Use `shared_preferences` with flat JSON. Per-channel quality stored as unlimited `Map<String, String>` - no eviction logic needed.

4. **Auth Token Priority:** Once authenticated, use auth token for ALL calls. Anonymous only for logged-out users.

---

## Quick Commands

```bash
# Run the app
cd smart_twitch_flutter && flutter run -d macos

# Check for errors
flutter analyze

# Upgrade packages
flutter pub upgrade --major-versions
```

---

## Reference: Original JS Codebase

The `app/` folder contains the original SmartTwitchTV JavaScript code. Use as reference for:

- **Chat:** `app/specific/ChatLive.js`, `app/specific/ChatLiveControls.js`
- **IRC Parser:** `app/thirdparty/irc-message.js`
- **Emotes:** `app/general/emojis.js`
- **OAuth:** `app/specific/AddCode.js`, `app/specific/AddUser.js`
- **Multi-stream:** `app/specific/PlayMulti.js`
- **Quality/HLS:** `app/specific/PlayHLS.js`

**Delete `app/` after Phase 2 (Chat) is complete.**
