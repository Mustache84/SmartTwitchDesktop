# SmartTwitchTV → Flutter Migration Plan

> **Status:** In Progress v1.5  
> **Date:** February 3, 2026  
> **Last Updated:** February 4, 2026  
> **Replaces:** `DESKTOP_FORK_PLAN.md` (Tauri/Rust approach - ABANDONED)

---

## Progress Log

### ✅ Phase 1: Foundation (COMPLETE)
- [x] Created Flutter project with desktop targets (macOS/Windows/Linux)
- [x] Integrated `fvp` v0.26.0 → **upgraded to v0.35.2** for MDK hardware-accelerated playback
- [x] Implemented `TwitchApiService` with GraphQL token fetching
- [x] Built `HlsUrlBuilder` with correct Twitch URL parameters
- [x] Single-stream playback working with live channels
- [x] Added macOS network entitlements for HTTP requests
- [x] Offline channel detection with user-friendly messaging

### ✅ Phase 3: Multi-Stream (PARTIAL - Core Complete)
- [x] Implemented `MultiStreamState` with Riverpod for 4-slot management
- [x] Built `MultiStreamGrid` with 2x2 layout
- [x] Audio focus switching via click (only one stream audible at a time)
- [x] Stream rotation functionality
- [x] Drag-and-drop slot reordering
- [x] `VideoControllerManager` singleton for persistent playback during drag-drop

### ✅ Home Screen & Browse (COMPLETE)
- [x] Twitch-like home screen with 10 featured streams (`home_screen.dart`)
- [x] Categories/games browsing with top categories section
- [x] **Stream preview on hover with audio** - snappy instant playback via pre-initialization
- [x] Collapsible sidebar with login placeholder (`collapsible_sidebar.dart`)
- [x] Search bar (placeholder UI - functionality pending)
- [x] `TwitchBrowseService` for fetching featured streams & top categories
- [x] `StreamPreviewCard` with thumbnail, title, channel, viewer count
- [x] `CategoryCard` with box art and viewer count

### ✅ Preview System Optimizations (COMPLETE)
- [x] `PreviewPlayerManager` - pre-initializes ALL 10 video controllers on home screen load
- [x] Parallel token fetching with `Future.wait` for fast preload
- [x] Hover delay reduced to 50ms (tunable in `ui_config.dart`)
- [x] Instant playback on hover - just calls `play()` on pre-initialized controller
- [x] RAM optimization: preview controllers disposed when navigating to PlayerScreen
- [x] Automatic re-preload when returning to home screen
- [x] `streamPreviewQuality` tunable setting (default: 'auto')
- [x] `streamPreviewAudioEnabled` tunable setting (default: true)
- [x] **Pending play fix**: hover during preload now queues auto-play when controller ready
- [x] Mouse exit clears pending play to prevent unwanted playback

### ✅ Package & Architecture Updates (COMPLETE)
- [x] Upgraded all packages to latest versions (`flutter pub upgrade --major-versions`)
  - `fvp` 0.26.0 → 0.35.2
  - `flutter_riverpod` 2.x → 3.1.0
  - `window_manager` 0.4.0 → 0.5.1
  - `dio` 5.4.0 → 5.7.0
- [x] Migrated Riverpod state from v2 `StateNotifier` to v3 `Notifier` pattern
- [x] Fixed CocoaPods dependencies for macOS build

### ✅ Phase 1.5: OAuth Foundation (COMPLETE)
OAuth is a prerequisite for player controls (subscription checks) and chat (authenticated messages).

**Flow:** Device Code Grant (same as original SmartTwitchTV) - no client secret in binary, refresh tokens included.

**Client ID:** `vrhsf9gxj2y4jntunres6mzber1fg1`

**Scopes:** `chat:read chat:edit user:read:follows user:read:subscriptions`

| Step | Description | Files | Status |
|------|-------------|-------|--------|
| 1.5.1 | Add `flutter_secure_storage`, `url_launcher` | `pubspec.yaml` | ✅ |
| 1.5.2 | Secure token storage (Keychain/Credential Manager/libsecret) | `lib/services/secure_token_storage.dart` | ✅ |
| 1.5.3 | Twitch auth service (Device Code Grant) | `lib/services/twitch_auth_service.dart` | ✅ |
| 1.5.4 | Token manager with auto-refresh (<5min expiry) | `lib/services/token_manager.dart` | ✅ |
| 1.5.5 | Auth state provider (Riverpod) | `lib/state/auth_provider.dart` | ✅ |
| 1.5.6 | Login screen (device code display, twitch.tv/activate) | `lib/screens/login_screen.dart` | ✅ |
| 1.5.7 | App routing (auth check on startup) | `main.dart` | ✅ |
| 1.5.8 | Update `TwitchApiService` to use auth token when available | `lib/services/twitch_api_service.dart` | ✅ |
| 1.5.9 | Sidebar login status with logout button | `lib/widgets/collapsible_sidebar.dart` | ✅ |

**Auth Strategy:** Once authenticated, use auth token for ALL API calls. Anonymous flow only for logged-out users.

**⚠️ TODO: Troubleshoot OAuth Client ID Issue**
> The OAuth Client ID `vrhsf9gxj2y4jntunres6mzber1fg1` returns HTTP 400 "Client-ID header is invalid" when used for `PlaybackAccessToken` requests. Currently falling back to anonymous client IDs for stream tokens. Need to investigate:
> - Is the Client ID registered correctly in Twitch Developer Console?
> - Does PlaybackAccessToken require a different Client ID than user auth?
> - Check if the Client ID was deleted/revoked

---

### ✅ Phase 1.6: Player Controls Foundation (COMPLETE)

| Step | Description | Files | Status |
|------|-------------|-------|--------|
| 1.6.1 | Add `shared_preferences`, enable 1440p codecs (`av1,h265,h264`) | `pubspec.yaml`, `hls_url_builder.dart` | ✅ |
| 1.6.2 | Settings service (unlimited per-channel quality storage) | `lib/services/settings_service.dart` | ✅ |
| 1.6.3 | HLS manifest parser (quality enumeration from `#EXT-X-STREAM-INF`) | `lib/services/hls_manifest_service.dart` | ✅ |
| 1.6.4 | Player controls state provider | `lib/state/player_controls_provider.dart` | ✅ |

**Settings Storage Structure (via shared_preferences):**
```json
{
  "quality.default": "auto",
  "quality.perChannel": { "xqc": "1080p60", "lirik": "source" },
  "latency.target": 2.0,
  "latency.lowLatencyMode": true,
  "player.volume": 0.8,
  "player.muted": false
}
```

**Per-Channel Storage:** Unlimited entries (~5KB per 100 channels). No eviction logic needed.

---

### ✅ Phase 1.7: Low Latency & Quality Selection (COMPLETE)

| Step | Description | Files | Status |
|------|-------------|-------|--------|
| 1.7.1 | Low latency service (buffer control, latency presets) | `lib/services/low_latency_service.dart` | ✅ |
| 1.7.2 | Quality selector widget (dropdown from manifest) | `lib/widgets/quality_selector.dart` | ✅ |
| 1.7.3 | Latency slider widget (0.5s - 10s range) | `lib/widgets/latency_slider.dart` | ✅ |
| 1.7.4 | Player controls overlay (play/pause, mute, volume) | `lib/screens/player_screen.dart` | ✅ |
| 1.7.5 | Keyboard shortcuts (Space, M, L, H, ↑↓) | `lib/screens/player_screen.dart` | ✅ |
| 1.7.6 | TwitchPlayerController wrapper for runtime control | `lib/widgets/video_widget.dart` | ✅ |

**Low Latency Implementation:**
- `fvp.registerWith(options: {'lowLatency': 1})` at startup
- `setBufferRange(0, targetMs, true)` based on slider
- Monitor `buffered()` vs target, adjust `setPlaybackRate(1.0-1.1)` for catch-up
- Let MDK handle codec fallback gracefully (request `av1,h265,h264`, MDK picks best)

---

### � Phase 1.8: Full Player Controls + DVR (IN PROGRESS)

| Step | Description | Files | Status |
|------|-------------|-------|--------|
| 1.8.1 | Auto-hide controls overlay after 3s inactivity | `lib/screens/player_screen.dart` | 🔲 |
| 1.8.2 | Fullscreen toggle (F key) | `lib/screens/player_screen.dart` | 🔲 |
| 1.8.3 | Stats overlay (Ctrl+D) | `lib/widgets/stats_overlay.dart` | 🔲 |
| 1.8.4 | "Sync All Streams" for multi-stream | `multi_stream_notifier.dart` | 🔲 |
| 1.8.5 | DVR/Rewind (check subscription via OAuth) | `lib/services/dvr_service.dart` | 🔲 |
| 1.8.6 | Quality selection that switches stream | `lib/screens/player_screen.dart` | 🔲 |

**Controls Overlay Features:**
- Play/pause, mute/volume slider, quality dropdown, latency slider
- Auto-hide after 3s inactivity, show on mouse move
- Fullscreen toggle, stats overlay (Ctrl+D)

**Keyboard Shortcuts:**
| Key | Action |
|-----|--------|
| Space | Play/Pause |
| M | Mute toggle |
| F | Fullscreen toggle |
| 1-9 | Quality selection |
| L | Low latency toggle |
| ↑↓ | Volume up/down |
| ←→ | Seek (VOD only) |

---

### 🔲 Phase 2: Chat System
- [ ] Wire up search functionality
- [ ] Implement `TwitchIrcClient` with WebSocket (auth or anonymous)
- [ ] Port IRC message parser from `irc-message.js`
- [ ] Implement `EmoteService` (BTTV/FFZ/7TV)
- [ ] Basic chat overlay rendering
- [ ] **TODO: Delete `app/` folder after Phase 2 complete** (kept for JS reference during chat port)

---

## Design Decisions & Technical Notes

### API Configuration
| Setting | Value | Notes |
|---------|-------|-------|
| **OAuth Client ID** | `vrhsf9gxj2y4jntunres6mzber1fg1` | Device Code Grant flow, user authentication |
| **OAuth Scopes** | `chat:read chat:edit user:read:follows user:read:subscriptions` | Chat, follows, DVR eligibility |
| Primary Client ID | `kd1unb4b3q4t58fwlpcbzcbnm76a8fp` | Anonymous token fetching (fallback) |
| Fallback Client IDs | `ue666qo983tsx6so1t0vnawi233wa`, `kimne78kx3ncx6brgo4mv6wki5h1ko` | Used if primary rate-limited |
| GraphQL Endpoint | `https://gql.twitch.tv/gql` | All token/browse queries |
| HLS Manifest | `https://usher.ttvnw.net/api/channel/hls/` | Stream URLs |
| Device Code Endpoint | `https://id.twitch.tv/oauth2/device` | OAuth device code request |
| Token Endpoint | `https://id.twitch.tv/oauth2/token` | OAuth token polling/refresh |
| Validate Endpoint | `https://id.twitch.tv/oauth2/validate` | Token validation |

### Architectural Patterns
| Pattern | Implementation | Rationale |
|---------|---------------|-----------|
| Video Controller Persistence | `VideoControllerManager` singleton | Prevents stream reload during drag-drop reordering |
| State Management | `flutter_riverpod` | Clean separation, testable, supports complex multi-stream state |
| UIUX Configurability | `ui_config.dart` constants | All timing/animation values tunable; expose in Settings later |

### UIUX Directive
> **All UIUX-related decisions should be user-configurable where sensible.** When adding new UIUX features, evaluate whether the setting should be exposed in the Settings screen for user customization.

---

## TODOs & Future Work

### Phase 1.5-1.8: OAuth + Player Controls (Current Priority)
See detailed task lists in Progress Log above.

### Phase 2: Chat System
- [ ] Wire up search functionality (placeholder UI exists)
- [ ] Implement `TwitchIrcClient` with WebSocket (auth or anonymous)
- [ ] Port IRC message parser from `irc-message.js`
- [ ] Implement `EmoteService` (BTTV/FFZ/7TV)
- [ ] Basic chat overlay rendering
- [ ] Delete `app/` folder after complete

### Phase 3: Personalized Home
- [ ] **IMPORTANT:** With OAuth complete, redesign home screen for personalized experience:
  - Followed channels (live first)
  - Followed categories/games
  - Recommendations based on watch history
  - User's clips and VODs
- [ ] **TODO (Release):** Revisit authenticated home page UIUX design before release

### Backlog
- [x] ~~Stream preview hover delay tunable (currently 300ms)~~ → Implemented in `ui_config.dart` (50ms default)
- [x] ~~Sidebar animation duration tunable (currently 150ms)~~ → Implemented in `ui_config.dart`
- [ ] VOD/Clip playback
- [ ] Picture-in-Picture mode
- [ ] 50/50 split view layout option
- [ ] Desktop notifications for followed channels going live
- [ ] Expose UIUX tunables in Settings screen

---

## Executive Summary

This document outlines the complete migration of SmartTwitchTV from a Tauri/WebView hybrid application to a **native Flutter desktop application**. The core video engine will use **MDK via `fvp`** for hardware-accelerated playback. All Android TV legacy code will be eliminated.

### Target Features (Updated)
| Feature | Priority | Status |
|---------|----------|--------|
| Hardware-Accelerated HLS Playback | P0 | ✅ Complete |
| 4-Way Multistream (Quad View) | P0 | ✅ Complete |
| Stream Preview on Hover | P0 | ✅ Complete |
| **OAuth Authentication** | P0 | ✅ Complete |
| **Player Controls Overlay** | P0 | ✅ Complete |
| **Quality Selection (1440p/4K)** | P0 | ✅ UI Complete (switching pending) |
| **Low Latency Mode** | P0 | ✅ Complete |
| Desktop Keyboard Shortcuts | P0 | ✅ Complete |
| Live IRC Chat with Overlay | P0 | 🔲 Phase 2 |
| BTTV/FFZ/7TV Emote Support | P1 | 🔲 Phase 2 |
| DVR/Rewind (Subscribers) | P1 | 🔲 Phase 1.8 |
| Personalized Home (Follows) | P1 | 🔲 Phase 3 |
| Picture-in-Picture Mode | P2 | 🔲 Backlog |
| 50/50 Split View | P2 | 🔲 Backlog |
| VOD/Clip Playback | P2 | 🔲 Backlog |

---

## 1. Stack & Dependencies

### Core Framework
```yaml
environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  # Video Engine (MDK-based)
  fvp: ^0.20.0
  video_player: ^2.8.0
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Networking
  dio: ^5.4.0
  web_socket_channel: ^2.4.0
  
  # Data & Storage
  shared_preferences: ^2.2.0
  hive: ^2.2.0
  hive_flutter: ^1.1.0
  
  # Desktop Utilities
  window_manager: ^0.3.0
  desktop_multi_window: ^0.2.0
  local_notifier: ^0.1.0
  
  # UI Helpers
  cached_network_image: ^3.3.0
  flutter_animate: ^4.3.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  hive_generator: ^2.0.0
```

### Platform Targets
```yaml
# flutter create --platforms=windows,macos,linux smart_twitch_desktop
```

| Platform | Video Backend | Notes |
|----------|---------------|-------|
| Windows | MDK (D3D11/Vulkan) | RTX Video Super Resolution support |
| macOS | MDK (Metal/VideoToolbox) | Native HW decode |
| Linux | MDK (VA-API/VDPAU) | X11/Wayland support |

---

## 2. Logic Extraction Strategy (JS → Dart)

### 2.1 Video Service Layer

**Source:** `app/specific/PlayHLS.js`

| JS Function | Dart Equivalent | Location |
|-------------|-----------------|----------|
| `PlayHLS_Start()` | `TwitchStreamService.startStream()` | `lib/services/twitch_stream_service.dart` |
| `PlayHLS_GetToken()` | `TwitchApiService.getPlaybackToken()` | `lib/services/twitch_api_service.dart` |
| `PlayHLS_GetTokenSuccess()` | Async/await pattern | N/A |
| `PlayHLS_playlist_url()` | `HlsUrlBuilder.buildStreamUrl()` | `lib/utils/hls_url_builder.dart` |
| `PlayHLS_playlist()` | `HlsService.fetchManifest()` | `lib/services/hls_service.dart` |
| `Play_CheckTokenSub()` | `TokenValidator.validateSubscription()` | `lib/utils/token_validator.dart` |

**Dart Implementation Sketch:**

```dart
// lib/services/twitch_api_service.dart
class TwitchApiService {
  final Dio _dio;
  
  // Port from PlayHLS.js: Play_live_token GraphQL query
  static const _liveTokenQuery = '''
    {"extensions":{"persistedQuery":{"sha256Hash":"ed230aa1e33e07eebb8928504583da78a5173989fadfb1ac94be06a04f3cdbe9","version":1}},
    "operationName":"PlaybackAccessToken","variables":{"isLive":true,"isVod":false,"login":"%LOGIN%","platform":"web","playerType":"site","vodID":""}}
  ''';
  
  Future<PlaybackToken> getPlaybackToken(String channelLogin) async {
    // Implement GQL call to gql.twitch.tv/gql
  }
}

// lib/utils/hls_url_builder.dart
class HlsUrlBuilder {
  // Port from PlayHLS.js: Play_original_live_links + Play_base_live_links
  static const _usherBase = 'https://usher.ttvnw.net/api/channel/hls/';
  
  static String buildStreamUrl({
    required String channel,
    required String token,
    required String signature,
  }) {
    // Construct full HLS manifest URL
  }
}
```

### 2.2 Chat Service Layer

**Source:** `app/specific/ChatLive.js`, `app/specific/ChatLiveControls.js`

| JS Function | Dart Equivalent | Location |
|-------------|-----------------|----------|
| `ChatLive_Init()` | `ChatService.initialize()` | `lib/services/chat_service.dart` |
| `ChatLive_Connect()` | `TwitchIrcClient.connect()` | `lib/services/twitch_irc_client.dart` |
| `ChatLive_ReceiveMsg()` | `IrcMessageParser.parse()` | `lib/utils/irc_message_parser.dart` |
| `ChatLive_LineAdd()` | `ChatController.addMessage()` | `lib/controllers/chat_controller.dart` |
| `ChatLive_SendMessage()` | `TwitchIrcClient.sendMessage()` | `lib/services/twitch_irc_client.dart` |
| `ChatLive_loadBadges()` | `BadgeService.loadGlobalBadges()` | `lib/services/badge_service.dart` |
| `ChatLive_LoadEmotesBTTV()` | `EmoteService.loadBttvEmotes()` | `lib/services/emote_service.dart` |
| `ChatLive_LoadEmotesFFZ()` | `EmoteService.loadFfzEmotes()` | `lib/services/emote_service.dart` |
| `ChatLive_LoadEmotes7TV()` | `EmoteService.load7tvEmotes()` | `lib/services/emote_service.dart` |

**IRC Connection Pattern (from ChatLive.js):**

```dart
// lib/services/twitch_irc_client.dart
class TwitchIrcClient {
  WebSocketChannel? _channel;
  
  // Port WebSocket URL from ChatLive.js
  static const _ircUrl = 'wss://irc-ws.chat.twitch.tv:443';
  
  Future<void> connect({String? accessToken, String? username}) async {
    _channel = WebSocketChannel.connect(Uri.parse(_ircUrl));
    
    if (accessToken != null && username != null) {
      // Authenticated connection
      _send('PASS oauth:$accessToken');
      _send('NICK $username');
      _send('USER $username 8 * :$username');
    } else {
      // Anonymous connection (from ChatLive.js)
      _send('PASS blah');
      _send('NICK justinfan${Random().nextInt(99999)}');
    }
    
    _send('CAP REQ :twitch.tv/tags twitch.tv/commands');
  }
  
  void joinChannel(String channel) {
    _send('JOIN #${channel.toLowerCase()}');
  }
}
```

**IRC Message Parser (port parseIRC from irc-message.js):**

```dart
// lib/utils/irc_message_parser.dart
class IrcMessage {
  final Map<String, String> tags;
  final String? prefix;
  final String command;
  final List<String> params;
  
  // Commands to handle (from ChatLive.js):
  // PRIVMSG, PING, JOIN, USERNOTICE, USERSTATE, NOTICE, ROOMSTATE, CLEARCHAT, CLEARMSG
}

class IrcMessageParser {
  static IrcMessage parse(String raw) {
    // Port regex logic from app/thirdparty/irc-message.js
  }
}
```

**Emote Service APIs:**

```dart
// lib/services/emote_service.dart
class EmoteService {
  // API endpoints from ChatLive.js
  static const _bttvApi = 'https://api.betterttv.net/3/cached/users/twitch/';
  static const _ffzApi = 'https://api.frankerfacez.com/v1/room/id/';
  static const _seventvApi = 'https://7tv.io/v3/users/twitch/';
  
  Future<List<Emote>> loadBttvEmotes(String channelId) async { ... }
  Future<List<Emote>> loadFfzEmotes(String channelId) async { ... }
  Future<List<Emote>> load7tvEmotes(String channelId) async { ... }
}
```

### 2.3 Multi-Stream Controller

**Source:** `app/specific/PlayMulti.js`

| JS Function | Dart Equivalent | Location |
|-------------|-----------------|----------|
| `Play_MultiStart()` | `MultiStreamController.startStream()` | `lib/controllers/multi_stream_controller.dart` |
| `Play_MultiEnd()` | `MultiStreamController.stopStream()` | Same |
| `Play_audioChange()` | `MultiStreamController.setAudioFocus()` | Same |
| `Play_Multi_SetInfo()` | State in `MultiStreamState` | `lib/state/multi_stream_state.dart` |
| `Play_Multi_IsFull()` | `MultiStreamState.isFull` getter | Same |
| `Play_Multi_findFirstEmpty()` | `MultiStreamState.firstEmptySlot` | Same |
| `Play_Multi_rotate()` | `MultiStreamController.rotatePositions()` | Same |

**State Architecture (porting Play_MultiArray from PlayMulti.js):**

```dart
// lib/state/multi_stream_state.dart
@freezed
class StreamSlot with _$StreamSlot {
  const factory StreamSlot({
    required int position,        // 0-3
    String? channelLogin,
    String? hlsUrl,
    StreamMetadata? metadata,
    @Default(false) bool hasAudio,
    DateTime? watchingSince,
  }) = _StreamSlot;
}

@riverpod
class MultiStreamController extends _$MultiStreamController {
  // Port Play_MultiArray_length = 4 from PlayMulti.js
  static const maxSlots = 4;
  
  @override
  List<StreamSlot> build() => List.generate(
    maxSlots, 
    (i) => StreamSlot(position: i),
  );
  
  // Port Play_audio_enable array logic
  void setAudioFocus(int slotIndex) {
    state = [
      for (int i = 0; i < maxSlots; i++)
        state[i].copyWith(hasAudio: i == slotIndex),
    ];
  }
  
  int? get firstEmptySlot {
    for (int i = 0; i < maxSlots; i++) {
      if (state[i].channelLogin == null) return i;
    }
    return null;
  }
  
  bool get isFull => firstEmptySlot == null;
}
```

---

## 3. UI Component Architecture

### 3.1 VideoWidget (fvp Integration)

```dart
// lib/widgets/video_widget.dart
class TwitchVideoWidget extends ConsumerStatefulWidget {
  final String hlsUrl;
  final bool hasAudio;
  final int slotIndex;
  
  @override
  ConsumerState<TwitchVideoWidget> createState() => _TwitchVideoWidgetState();
}

class _TwitchVideoWidgetState extends ConsumerState<TwitchVideoWidget> {
  late VideoPlayerController _controller;
  
  @override
  void initState() {
    super.initState();
    // fvp automatically registers as the video backend
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.hlsUrl),
    );
    _controller.initialize().then((_) {
      _controller.setVolume(widget.hasAudio ? 1.0 : 0.0);
      _controller.play();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: VideoPlayer(_controller),
    );
  }
}
```

### 3.2 ChatOverlay Widget

**Port positioning from Play_ChatPositionVal in Play.js:**

```dart
// lib/widgets/chat_overlay.dart
enum ChatPosition {
  bottomRight,  // { top: 51.8, left: 75.1 }
  middleRight,  // { top: 33, left: 75.1 }
  topRight,     // { top: 0.2, left: 75.1 }
  topCenter,    // { top: 0.2, left: 38.3 }
  topLeft,      // { top: 0.2, left: 0.2 }
  middleLeft,   // { top: 33, left: 0.2 }
  bottomLeft,   // { top: 51.8, left: 0.2 }
  bottomCenter, // { top: 51.8, left: 38.3 }
}

class ChatOverlay extends ConsumerWidget {
  final ChatPosition position;
  final double opacity;
  final double heightPercent; // Port Play_ChatSizeVal
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    
    return Positioned(
      top: _getTop(position, context),
      left: _getLeft(position, context),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.24,
          height: MediaQuery.of(context).size.height * heightPercent,
          child: ChatMessageList(messages: messages),
        ),
      ),
    );
  }
}
```

### 3.3 MultiGridView Layout

```dart
// lib/widgets/multi_grid_view.dart
class MultiStreamGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(multiStreamControllerProvider);
    
    return GridView.count(
      crossAxisCount: 2, // 2x2 grid
      childAspectRatio: 16 / 9,
      children: [
        for (final slot in slots)
          _buildSlot(slot, ref),
      ],
    );
  }
  
  Widget _buildSlot(StreamSlot slot, WidgetRef ref) {
    if (slot.hlsUrl == null) {
      return const EmptySlotPlaceholder();
    }
    
    return GestureDetector(
      onTap: () => ref.read(multiStreamControllerProvider.notifier)
          .setAudioFocus(slot.position),
      child: Stack(
        children: [
          TwitchVideoWidget(
            hlsUrl: slot.hlsUrl!,
            hasAudio: slot.hasAudio,
            slotIndex: slot.position,
          ),
          if (slot.hasAudio)
            const Positioned(
              top: 8, right: 8,
              child: Icon(Icons.volume_up, color: Colors.white),
            ),
          StreamInfoOverlay(metadata: slot.metadata),
        ],
      ),
    );
  }
}
```

### 3.4 Keyboard Shortcuts

**Port shortcuts from DESKTOP_FORK_PLAN.md:**

```dart
// lib/widgets/keyboard_shortcuts_wrapper.dart
class KeyboardShortcutsWrapper extends ConsumerWidget {
  final Widget child;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        // Playback
        const SingleActivator(LogicalKeyboardKey.space): 
            () => ref.read(playerControllerProvider.notifier).togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): 
            () => ref.read(playerControllerProvider.notifier).seek(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): 
            () => ref.read(playerControllerProvider.notifier).seek(10),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): 
            () => ref.read(playerControllerProvider.notifier).seek(-30),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): 
            () => ref.read(playerControllerProvider.notifier).seek(30),
        
        // Volume
        const SingleActivator(LogicalKeyboardKey.arrowUp): 
            () => ref.read(playerControllerProvider.notifier).adjustVolume(0.1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): 
            () => ref.read(playerControllerProvider.notifier).adjustVolume(-0.1),
        const SingleActivator(LogicalKeyboardKey.keyM): 
            () => ref.read(playerControllerProvider.notifier).toggleMute(),
        
        // View
        const SingleActivator(LogicalKeyboardKey.keyF): 
            () => ref.read(windowControllerProvider.notifier).toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.escape): 
            () => _handleEscape(ref),
        const SingleActivator(LogicalKeyboardKey.keyC): 
            () => ref.read(chatOverlayProvider.notifier).toggleVisibility(),
        const SingleActivator(LogicalKeyboardKey.keyC, shift: true): 
            () => ref.read(chatOverlayProvider.notifier).cyclePosition(),
        const SingleActivator(LogicalKeyboardKey.keyT): 
            () => ref.read(layoutProvider.notifier).toggleTheaterMode(),
        
        // Quality (1-9)
        for (int i = 1; i <= 9; i++)
          SingleActivator(LogicalKeyboardKey(0x30 + i)): 
              () => ref.read(playerControllerProvider.notifier).setQuality(i - 1),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
```

---

## 4. The Destruction Manifesto

### Immediate Deletion List

| Path | Reason |
|------|--------|
| `src-tauri/` | **ENTIRE FOLDER** - Rust/Tauri backend no longer needed |
| `app/index.html` | WebView entry point - replaced by Flutter |
| `app/etc/index.html` | Secondary HTML entry |
| `app/Extrapage/index.html` | Extra page HTML |
| `app/css/` | **ENTIRE FOLDER** - All CSS replaced by Flutter widgets |
| `app/specific/OSInterface.js` | Android Java bridge shims |
| `app/specific/BrowserTest.js` | Browser-only testing utilities |
| `app/general/TVKeyValue.js` | TV remote key mappings |
| `app/thirdparty/hls.min.js` | HLS.js - replaced by MDK/fvp |
| `app/thirdparty/kapchat.js` | Legacy chat overlay |
| `Cargo.toml` | Rust manifest (root level if exists) |
| `Cargo.lock` | Rust lockfile |
| `tauri.conf.json` | Tauri configuration |
| `DESKTOP_FORK_PLAN.md` | Superseded by this document |

### Android-Specific Code Patterns to Remove

When porting JS files, **DELETE** any code matching these patterns:

```javascript
// DELETE: All Android.* calls
if (Main_Android) { ... }
Android.mNotificationServerStart(...)
Android.mSetPlayer(...)
Android.mSeekTo(...)
Android.mSwitchPlayerAudio(...)
Android.msetPlaybackSpeed(...)
Android.mSetBuffer(...)
Android.mLowLatency(...)
Android.mrunalivetv(...)

// DELETE: ExoPlayer-specific settings
OSInterface_SetBuffer()
OSInterface_LowLatency()
OSInterface_RestartPlayer()

// DELETE: TV-specific UI patterns
Main_isTV
Settings_value.tv_*
```

### Files to Retain (for reference during porting)

| Path | Port To |
|------|---------|
| `app/specific/PlayHLS.js` | `lib/services/twitch_stream_service.dart` |
| `app/specific/ChatLive.js` | `lib/services/twitch_irc_client.dart` |
| `app/specific/ChatLiveControls.js` | `lib/widgets/chat_input_widget.dart` |
| `app/specific/PlayMulti.js` | `lib/controllers/multi_stream_controller.dart` |
| `app/specific/Play.js` | `lib/controllers/player_controller.dart` |
| `app/specific/PlayVod.js` | `lib/services/vod_service.dart` |
| `app/specific/PlayClip.js` | `lib/services/clip_service.dart` |
| `app/specific/Settings.js` | `lib/services/settings_service.dart` |
| `app/specific/Users.js` | `lib/services/user_service.dart` |
| `app/specific/Search.js` | `lib/services/search_service.dart` |
| `app/languages/*.js` | `lib/l10n/` (Flutter intl) |
| `app/thirdparty/irc-message.js` | `lib/utils/irc_message_parser.dart` |
| `app/general/emojis.js` | `lib/data/emoji_data.dart` |

---

## 5. Project Structure (Final)

```
smart_twitch_desktop/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── controllers/
│   │   ├── multi_stream_controller.dart
│   │   ├── player_controller.dart
│   │   └── chat_controller.dart
│   ├── services/
│   │   ├── twitch_api_service.dart
│   │   ├── twitch_stream_service.dart
│   │   ├── twitch_irc_client.dart
│   │   ├── emote_service.dart
│   │   ├── badge_service.dart
│   │   ├── settings_service.dart
│   │   └── notification_service.dart
│   ├── models/
│   │   ├── stream_metadata.dart
│   │   ├── chat_message.dart
│   │   ├── emote.dart
│   │   ├── badge.dart
│   │   └── playback_token.dart
│   ├── state/
│   │   ├── multi_stream_state.dart
│   │   ├── chat_state.dart
│   │   └── settings_state.dart
│   ├── widgets/
│   │   ├── video_widget.dart
│   │   ├── chat_overlay.dart
│   │   ├── chat_message_list.dart
│   │   ├── multi_grid_view.dart
│   │   ├── emote_picker.dart
│   │   └── keyboard_shortcuts_wrapper.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── player_screen.dart
│   │   ├── multi_player_screen.dart
│   │   └── settings_screen.dart
│   ├── utils/
│   │   ├── hls_url_builder.dart
│   │   ├── irc_message_parser.dart
│   │   └── token_validator.dart
│   └── l10n/
│       └── (Flutter ARB files)
├── windows/
├── macos/
├── linux/
├── test/
└── pubspec.yaml
```

---

## 6. Migration Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Create Flutter project with desktop targets
- [ ] Integrate `fvp` and verify HW acceleration
- [ ] Implement `TwitchApiService` with token fetching
- [ ] Basic single-stream playback working

### Phase 2: Chat System (Week 3-4)
- [ ] Implement `TwitchIrcClient` with WebSocket
- [ ] Port IRC message parser
- [ ] Implement `EmoteService` (BTTV/FFZ/7TV)
- [ ] Basic chat overlay rendering

### Phase 3: Multi-Stream (Week 5-6)
- [ ] Implement `MultiStreamController` state
- [ ] Build `MultiGridView` widget
- [ ] Audio focus switching between streams
- [ ] Chat overlay positioning system

### Phase 4: Polish (Week 7-8)
- [ ] Full keyboard shortcut support
- [ ] Settings persistence
- [ ] VOD/Clip playback
- [ ] Desktop notifications
- [ ] Window management (PiP mode)

---

## Appendix: API Reference

### Twitch Endpoints Used

| Purpose | Endpoint |
|---------|----------|
| GraphQL (Tokens) | `https://gql.twitch.tv/gql` |
| Helix API | `https://api.twitch.tv/helix/` |
| HLS Manifest | `https://usher.ttvnw.net/api/channel/hls/{channel}.m3u8` |
| IRC WebSocket | `wss://irc-ws.chat.twitch.tv:443` |
| Global Badges | `https://badges.twitch.tv/v1/badges/global/display` |
| Channel Badges | `https://badges.twitch.tv/v1/badges/channels/{id}/display` |

### Third-Party Emote APIs

| Service | Endpoint |
|---------|----------|
| BTTV | `https://api.betterttv.net/3/cached/users/twitch/{id}` |
| FFZ | `https://api.frankerfacez.com/v1/room/id/{id}` |
| 7TV | `https://7tv.io/v3/users/twitch/{id}` |

---

*This plan supersedes DESKTOP_FORK_PLAN.md. The Tauri/Rust approach is officially abandoned.*
