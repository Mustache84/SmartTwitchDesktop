# AI Agent Context File

> **Last Updated:** February 5, 2026  
> **Current Phase:** 1.9 (Headless Integrity Engine) - **COMPLETE**  
> **Target Platforms:** macOS, Windows (Linux removed)  
> **For detailed task breakdown, see:** `FLUTTER_MIGRATION_PLAN.md`

---

## ✅ NEW: Service Lifecycle & Dependency Injection (Phase 1.5.1)

Implemented proper desktop app architecture for graceful shutdown and resource management.

### Key Components
| Component | File | Purpose |
|-----------|------|--------|
| `Disposable` | `lib/core/interfaces/disposable.dart` | Interface for services needing cleanup |
| `ServiceLocator` | `lib/core/di/service_locator.dart` | GetIt-based DI with shutdown logic |
| `WindowListener` | `lib/main.dart` | Graceful shutdown on window close |

### Usage Pattern
```dart
// Access any service:
final authService = sl<TwitchAuthService>();
final tokenManager = sl<TokenManager>();

// Window close triggers automatic cleanup:
// main.dart → onWindowClose() → ServiceLocator.disposeAll()
```

### Registered Services
- `SettingsService` - Persistent settings
- `TwitchAuthService` - OAuth Device Code Grant
- `TokenManager` - Token refresh (implements `Disposable`)
- `TwitchApiService` - GraphQL API
- `TwitchBrowseService` - Browse data
- `HlsManifestService` - Quality parsing
- `LowLatencyService` - Latency control (implements `Disposable`)
- `PreviewPlayerManager` - Video controllers (implements `Disposable`)

---

## ⚠️ CRITICAL: Phase 1.9 Architecture Pivot

Twitch now requires `Client-Integrity` tokens for playback. Static client IDs are being blocked. Phase 1.9 implements a "Ghost Browser" to harvest valid integrity tokens.

**The Problem:** Direct GQL calls with static client IDs return 403 Forbidden.

**The Solution:** Hidden WebView runs real Twitch site, intercepts integrity tokens, syncs cookies to `fvp` player.

---

## Project Overview

**SmartTwitchDesktop** is a native Flutter desktop app (macOS/Windows) for watching Twitch streams. It's a migration from the original SmartTwitchTV Android/web app, keeping the JS codebase in `app/` as reference only.

### Tech Stack
| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.38.9 (desktop) |
| Video Engine | `fvp` v0.35.2 (MDK-based, hardware-accelerated) |
| State Management | `flutter_riverpod` v3.1.0 (Notifier pattern) |
| Dependency Injection | `get_it` v8.0.3 (lazy singletons) |
| HTTP | `dio` v5.7.0 |
| **Headless Browser** | `flutter_inappwebview` v6.1.0 (Phase 1.9) |
| Twitch API | GraphQL via `gql.twitch.tv/gql` |

### Project Structure
```
SmartTwitchDesktop/
├── smart_twitch_flutter/     # Flutter app (active development)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/           # Constants (twitch_constants, browser_constants)
│   │   ├── core/             # Core architecture
│   │   │   ├── di/           # Dependency injection (service_locator.dart)
│   │   │   └── interfaces/   # Contracts (disposable.dart)
│   │   ├── models/           # Data models (TwitchSession)
│   │   ├── screens/          # Full-page screens
│   │   ├── services/         # API, video, auth, integrity services
│   │   ├── state/            # Riverpod providers (auth, integrity, player)
│   │   ├── utils/            # Helpers, config, AppLogger
│   │   └── widgets/          # Reusable UI components
│   ├── CHANGELOG.md          # Version history
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

### ✅ Service Lifecycle & Dependency Injection (Phase 1.5.1)
- `Disposable` interface for services with cleanup needs
- `ServiceLocator` (GetIt) for lazy singleton registration
- `WindowListener` integration for graceful app shutdown
- Services implement `Disposable`: `TokenManager`, `LowLatencyService`, `PreviewPlayerManager`
- Automatic disposal on window close (timers, controllers, connections)

---

## ✅ Phase 1.9: Headless Integrity Engine (COMPLETE)

Successfully implemented "Ghost Browser" architecture to bypass Twitch's API hardening.

### Architecture: Ghost Browser
```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (MaterialApp)                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Stack                                                 │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Main UI (HomeScreen, PlayerScreen, etc.)       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Ghost WebView (1x1 pixel, behind UI)           │  │  │
│  │  │  - Loads twitch.tv                              │  │  │
│  │  │  - Intercepts GQL → extracts Client-Integrity   │  │  │
│  │  │  - Blocks .ts/.m3u8/video-weaver URLs           │  │  │
│  │  │  - Syncs cookies to fvp                         │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1.9 Task List
| # | Task | File | Status |
|---|------|------|--------|
| 1 | Add `flutter_inappwebview` dependency | `pubspec.yaml` | ✅ |
| 2 | Update macOS entitlements (JIT, audio-input) | `macos/Runner/*.entitlements` | ✅ |
| 3 | Delete Linux target folder | `linux/` | 🔲 (deferred) |
| 4 | Create `BrowserConstants` (User-Agent) | `lib/utils/browser_constants.dart` | ✅ |
| 5 | Create `TwitchSession` model | `lib/models/twitch_session.dart` | ✅ |
| 6 | Create `TwitchIntegrityService` | `lib/services/twitch_integrity_service.dart` | ✅ |
| 7 | Create `IntegrityProvider` | `lib/state/integrity_provider.dart` | ✅ |
| 8 | Create `BehavioralNoiseService` | `lib/services/behavioral_noise_service.dart` | ✅ |
| 9 | Create `IntegrityWebViewFallback` | `lib/widgets/integrity_webview_fallback.dart` | ✅ |
| 10 | Create `IntegrityStatusIndicator` | `lib/widgets/debug/integrity_status_indicator.dart` | ✅ |
| 11 | Refactor `TwitchApiService` | `lib/services/twitch_api_service.dart` | ✅ |
| 12 | Update `VideoWidget` | `lib/widgets/video_widget.dart` | ✅ |
| 13 | Update `VideoControllerManager` | `lib/widgets/video_controller_manager.dart` | ✅ |
| 14 | Update `PreviewPlayerManager` | `lib/services/preview_player_manager.dart` | ✅ |
| 15 | Update `PlayerScreen` | `lib/screens/player_screen.dart` | ✅ |
| 16 | Update `HomeScreen` | `lib/screens/home_screen.dart` | ✅ |
| 17 | Fix `Disposable` ambiguous import | `lib/core/di/service_locator.dart` | ✅ |

---

## Upcoming Phases

### Phase 1.8: Full Player Controls + DVR (Deferred)
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

### Existing Files (Phase 1.9 will modify)
| File | Purpose | Phase 1.9 Changes |
|------|---------|-------------------|
| `lib/services/twitch_api_service.dart` | GraphQL token fetching | Inject integrity headers |
| `lib/widgets/video_widget.dart` | Video player | Add harvested cookies/UA |
| `lib/main.dart` | App entry point | Add WidgetsBindingObserver |
| `lib/config/twitch_constants.dart` | API constants | Static client IDs deprecated |

### New Files (Phase 1.9 will create)
| File | Purpose |
|------|---------|
| `lib/config/browser_constants.dart` | Centralized User-Agent string |
| `lib/utils/app_logger.dart` | Structured logging with prefixes |
| `lib/models/twitch_session.dart` | Integrity tokens + cookies model |
| `lib/services/twitch_integrity_service.dart` | Ghost WebView harvester |
| `lib/state/integrity_provider.dart` | Riverpod state for integrity |
| `lib/services/behavioral_noise_service.dart` | Shadow nav + heartbeat |
| `lib/widgets/captcha_modal.dart` | Blocking CAPTCHA dialog |
| `lib/widgets/integrity_spinner.dart` | Loading + timeout UI |

### Reference Files
| File | Purpose |
|------|---------|
| `lib/services/twitch_auth_service.dart` | OAuth Device Code Grant flow |
| `lib/services/settings_service.dart` | Persistent settings via shared_preferences |
| `lib/services/low_latency_service.dart` | Buffer control, latency presets |
| `lib/services/hls_manifest_service.dart` | Parses HLS manifests for quality options |
| `lib/utils/hls_url_builder.dart` | Constructs Twitch HLS manifest URLs |
| `lib/services/preview_player_manager.dart` | Pre-initializes video controllers for hover preview |
| `lib/state/multi_stream_notifier.dart` | Riverpod state for 4-slot multi-stream |
| `lib/state/auth_provider.dart` | Riverpod state for authentication |
| `lib/widgets/quality_selector.dart` | Quality dropdown from HLS manifest |
| `lib/widgets/latency_slider.dart` | Latency control widgets |
| `lib/utils/ui_config.dart` | Tunable UIUX constants (expose in Settings later) |

---

## API Configuration

### ⚠️ Phase 1.9 Migration: Static → Harvested

**Before (Static - DEPRECATED):**
```dart
// OLD: lib/config/twitch_constants.dart
const twitchGqlClientId = 'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';
headers['Client-ID'] = twitchGqlClientId;  // ❌ Will be blocked
```

**After (Harvested - Phase 1.9):**
```dart
// NEW: From TwitchIntegrityService
final session = ref.read(integrityProvider).session;
headers['Client-ID'] = session.clientId;           // ✅ Harvested
headers['Client-Integrity'] = session.integrity;   // ✅ Required
headers['X-Device-Id'] = session.deviceId;         // ✅ Required
headers['Cookie'] = session.cookieHeader;          // ✅ Session sync
```

### Critical: User-Agent Fingerprint
```dart
// MUST be identical in both WebView AND fvp
// lib/config/browser_constants.dart
const twitchUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
```

### Centralized Constants (Still Valid for OAuth)
| Constant | Value | Purpose |
|----------|-------|---------|
| **`twitchClientId`** | `vrhsf9gxj2y4jntunres6mzber1fg1` | OAuth Client ID - Device Code Grant |
| `twitchGqlEndpoint` | `https://gql.twitch.tv/gql` | GraphQL endpoint |
| `twitchHelixEndpoint` | `https://api.twitch.tv/helix` | Official Helix API |
| `twitchOAuthScopes` | `[chat:read, chat:edit, ...]` | Required OAuth scopes |

---

## Design Principles

1. **UIUX Configurability:** All timing/animation values should be tunable via `ui_config.dart` and eventually exposed in Settings.

2. **Let MDK Handle It:** For codec detection, fallback, etc. - request all codecs, MDK picks the best available.

3. **Simple Settings Storage:** Use `shared_preferences` with flat JSON. Per-channel quality stored as unlimited `Map<String, String>` - no eviction logic needed.

4. **Auth Token Priority:** Once authenticated, use auth token for ALL calls. Anonymous only for logged-out users.

5. **Structured Logging:** Use `AppLogger` with prefixes (`[Integrity]`, `[Noise]`, etc.). Never use `print()`.

6. **Graceful Degradation:** 10s timeout on integrity harvest → show helpful error message about frontend obfuscation.

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
