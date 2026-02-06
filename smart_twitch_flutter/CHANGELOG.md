# Changelog

All notable changes to SmartTwitchDesktop Flutter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.1.9] - 2026-02-05

### Added
- **Phase 1.9: Headless Integrity Engine (Complete)**
  - `flutter_inappwebview: ^6.1.5` dependency for hidden browser token harvesting
  - `TwitchIntegrityService` - Headless WebView that loads Twitch and intercepts GQL headers
  - `TwitchSession` model - Holds Client-ID, Client-Integrity, Device-ID, Authorization, cookies
  - `BrowserConstants` - Centralized Chrome 122 User-Agent (`lib/utils/browser_constants.dart`)
  - `IntegrityProvider` - Riverpod state management for integrity tokens
  - `BehavioralNoiseService` - Shadow navigation + randomized heartbeat (3-7 min intervals)
  - `IntegrityWebViewFallback` - 1x1 pixel visible WebView for Windows fallback
  - `IntegrityStatusIndicator` - Debug UI showing 🔴🟡🟢 status with click-to-refresh

### Changed
- **TwitchApiService** - Now injects integrity headers from `TwitchIntegrityService`
  - Automatic retry on 403 with token refresh
  - Enhanced logging with emojis (`[API] 🔐`, `[API] ⚠️`, `[API] ✅`)
- **VideoWidget** - Accepts optional `integritySession` parameter for header injection
- **VideoControllerManager** - `getController()` accepts optional `TwitchSession` for headers
- **PersistentVideoWidget** - Watches `integritySessionProvider` for multi-stream players
- **PreviewPlayerManager** - `preloadAllStreams()` accepts optional `TwitchSession` for previews
- **PlayerScreen** - Passes `integritySession` to `TwitchVideoWidget`
- **HomeScreen** - Passes `integritySession` to `PreviewPlayerManager.preloadAllStreams()`
- **main.dart** - Wrapped app with `IntegrityInitializer`, watches `behavioralNoiseServiceProvider`
- **CollapsibleSidebar** - Added `IntegrityStatusIndicator` widget
- **service_locator.dart** - Fixed `Disposable` ambiguous import (hide from get_it)
- macOS entitlements updated with `com.apple.security.device.audio-input` and `com.apple.security.cs.allow-jit`

### Architecture
```
IntegrityInitializer → TwitchIntegrityService (harvests tokens)
         ↓
integritySessionProvider (Riverpod state)
         ↓
    ┌────┴────┐
    ↓         ↓
PlayerScreen  HomeScreen
    ↓              ↓
VideoWidget   PreviewPlayerManager
    ↓              ↓
VideoPlayerController (with Client-ID, Client-Integrity, X-Device-Id, Cookie headers)
```

### Breaking Changes
- Video playback now requires integrity tokens (harvested automatically on startup)
- All player widgets must receive session from `integritySessionProvider`

---

## [0.1.8] - 2026-02-05

### Added
- **Phase 1.5.1: Service Lifecycle & Dependency Injection**
  - `Disposable` interface for services requiring cleanup (`lib/core/interfaces/disposable.dart`)
  - `ServiceLocator` class with GetIt-based lazy singleton registration (`lib/core/di/service_locator.dart`)
  - `WindowListener` implementation in `main.dart` for graceful shutdown
  - Automatic `disposeAll()` on window close (prevents memory leaks on long-running desktop sessions)
  - Added `get_it: ^8.0.3` dependency

### Changed
- `SmartTwitchApp` is now a `StatefulWidget` with `WindowListener` mixin
- `TokenManager` now implements `Disposable` (cancels refresh timer)
- `LowLatencyService` now implements `Disposable` (cancels catch-up timer)
- `PreviewPlayerManager` now implements `Disposable` (disposes video controllers)
- `SettingsService` initialization moved into `ServiceLocator.initialize()`
- All services registered as lazy singletons via `sl<ServiceType>()`

### Architecture
```dart
// Access any service:
final tokenManager = sl<TokenManager>();

// Graceful shutdown:
onWindowClose() → ServiceLocator.disposeAll() → windowManager.destroy()
```

---

## [0.1.7] - 2026-02-04

### Added
- **Phase 1.7: Low Latency & Quality Selection**
  - `LowLatencyService` with buffer control and latency presets
  - `QualitySelector` widget with dropdown from HLS manifest
  - `LatencySlider` widget (0.5s - 10s range)
  - Player controls overlay (play/pause, mute, volume)
  - Keyboard shortcuts: Space, M, L, H, ↑↓
  - `TwitchPlayerController` wrapper for runtime control

### Changed
- `fvp.registerWith(options: {'lowLatency': 1})` enabled at startup
- MDK handles codec fallback gracefully (av1 → h265 → h264)

---

## [0.1.6] - 2026-02-04

### Added
- **Phase 1.6: Player Controls Foundation**
  - `SettingsService` with per-channel quality storage
  - `HlsManifestService` parser for quality enumeration
  - `PlayerControlsProvider` Riverpod state
  - 1440p codec support (`av1,h265,h264`)

---

## [0.1.5] - 2026-02-04

### Added
- **Phase 1.5: OAuth Foundation**
  - `SecureTokenStorage` (Keychain/Credential Manager)
  - `TwitchAuthService` with Device Code Grant flow
  - `TokenManager` with auto-refresh (<5min expiry)
  - `AuthProvider` Riverpod state
  - `LoginScreen` with device code display
  - Sidebar login status with logout button

### Fixed
- **OAuth Client ID Issue** - Centralized client IDs in `twitch_constants.dart`
  - `twitchClientId` for OAuth + Helix API
  - `twitchGqlClientId` for GraphQL API (blessed client ID)

---

## [0.1.4] - 2026-02-03

### Added
- **Preview System Optimizations**
  - `PreviewPlayerManager` pre-initializes all 10 video controllers
  - Parallel token fetching with `Future.wait`
  - Hover delay reduced to 50ms (tunable in `ui_config.dart`)
  - RAM optimization: dispose preview controllers on navigation
  - Pending play fix: queue auto-play during preload

### Changed
- Upgraded all packages to latest versions
  - `fvp` 0.26.0 → 0.35.2
  - `flutter_riverpod` 2.x → 3.1.0
  - `window_manager` 0.4.0 → 0.5.1
  - `dio` 5.4.0 → 5.7.0
- Migrated Riverpod from v2 `StateNotifier` to v3 `Notifier` pattern

---

## [0.1.3] - 2026-02-02

### Added
- **Home Screen & Browse**
  - Twitch-like home screen with 10 featured streams
  - Categories/games browsing with top categories section
  - Stream preview on hover with audio
  - Collapsible sidebar with login placeholder
  - Search bar (placeholder UI)
  - `TwitchBrowseService` for fetching streams & categories
  - `StreamPreviewCard` and `CategoryCard` widgets

---

## [0.1.2] - 2026-02-01

### Added
- **Phase 3: Multi-Stream (Partial)**
  - `MultiStreamState` with Riverpod for 4-slot management
  - `MultiStreamGrid` with 2x2 layout
  - Audio focus switching via click
  - Stream rotation functionality
  - Drag-and-drop slot reordering
  - `VideoControllerManager` singleton for persistent playback

---

## [0.1.1] - 2026-01-31

### Added
- **Phase 1: Foundation**
  - Flutter project with desktop targets (macOS/Windows)
  - `fvp` integration for MDK hardware-accelerated playback
  - `TwitchApiService` with GraphQL token fetching
  - `HlsUrlBuilder` with correct Twitch URL parameters
  - Single-stream playback working
  - macOS network entitlements
  - Offline channel detection

---

## [0.1.0] - 2026-01-30

### Added
- Initial Flutter project creation
- Project structure setup
- Basic dependencies configured
