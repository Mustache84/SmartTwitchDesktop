# SmartTwitchTV Desktop Fork - Implementation Plan

## Overview

This document outlines the complete plan to fork SmartTwitchTV from an Android/TV app to a native desktop application using Tauri. The goal is to remove all Android-specific code while preserving all user-facing features.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Tauri Shell (Rust)                                         │
│  ├── Window management                                      │
│  ├── Global hotkeys                                         │
│  ├── System tray (optional)                                 │
│  ├── Auto-updater (GitHub releases)                         │
│  └── CORS proxy for Twitch API                              │
├─────────────────────────────────────────────────────────────┤
│  Desktop Interface Layer (DesktopInterface.js)              │
│  ├── Replaces OSInterface.js                                │
│  ├── Direct browser APIs where possible                     │
│  └── Tauri invoke() for native features                     │
├─────────────────────────────────────────────────────────────┤
│  HLS.js Player                                              │
│  ├── Quality selection (manual + ABR)                       │
│  ├── Low-latency mode                                       │
│  ├── Playback speed control                                 │
│  └── Multi-instance support (for future multi-stream)       │
├─────────────────────────────────────────────────────────────┤
│  SmartTwitchTV Web App (Modified)                           │
│  ├── Main.js (platform detection: Main_IsDesktop)           │
│  ├── Play*.js (adapted for HLS.js)                          │
│  ├── Chat*.js (unchanged)                                   │
│  └── UI/Screens (keyboard navigation adapted)               │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Foundation (Current State → Working Desktop App)

### 1.1 Platform Detection
**Files:** `Main.js`

Replace Android detection with desktop detection:
```javascript
// OLD
Main_IsOn_OSInterface = OSInterface_getversion() !== '';

// NEW
Main_IsDesktop = window.__TAURI__ !== undefined;
Main_IsOn_OSInterface = false; // Disable Android path entirely
```

### 1.2 Create DesktopInterface.js
**New File:** `app/specific/DesktopInterface.js`

This replaces `OSInterface.js` with clean desktop implementations:

| Function | Implementation |
|----------|---------------|
| HTTP requests | `fetch()` + Tauri CORS proxy |
| Clipboard | `navigator.clipboard` API |
| Playback control | HLS.js API |
| Quality selection | HLS.js levels API |
| Volume | HTML5 `<video>.volume` |
| Close/Minimize | Tauri window API |

### 1.3 Keyboard Input Normalization
**File:** `TVKeyValue.js`

Remove TV remote key codes, use standard keyboard:
```javascript
var KEY_ENTER = 13;      // Enter
var KEY_RETURN = 27;     // Escape (back/cancel)
var KEY_UP = 38;
var KEY_DOWN = 40;
var KEY_LEFT = 37;
var KEY_RIGHT = 39;
var KEY_KEYBOARD_BACKSPACE = 8;
// Remove: KEY_RED, KEY_GREEN, KEY_YELLOW, KEY_BLUE, etc.
```

### 1.4 Remove Android Bridge
**Delete:** `src-tauri/bridge/android-bridge.js`
**Modify:** `src-tauri/src/lib.rs` - Remove bridge injection

---

## Phase 2: Player Implementation (HLS.js)

### 2.1 Add HLS.js Dependency
**File:** `index.html` or bundled

```html
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
```

### 2.2 Create Desktop Player Module
**New File:** `app/specific/PlayDesktop.js`

Core player implementation using HLS.js:

```javascript
var DesktopPlayer = {
    hls: null,
    video: null,

    init: function(videoElement) {
        this.video = videoElement;
        if (Hls.isSupported()) {
            this.hls = new Hls({
                lowLatencyMode: true,
                enableWorker: true,
                backBufferLength: 90
            });
        }
    },

    loadStream: function(url, playlistContent) {
        // Load HLS stream
    },

    setQuality: function(levelIndex) {
        // -1 for auto, else specific level
        this.hls.currentLevel = levelIndex;
    },

    getQualities: function() {
        return this.hls.levels.map((level, i) => ({
            index: i,
            height: level.height,
            bitrate: level.bitrate
        }));
    },

    setLatencyMode: function(mode) {
        // Configure low latency
    },

    setPlaybackSpeed: function(speed) {
        this.video.playbackRate = speed;
    }
};
```

### 2.3 Adapt Play.js, PlayVod.js, PlayClip.js
**Files:** `Play.js`, `PlayVod.js`, `PlayClip.js`, `PlayHLS.js`, `PlayEtc.js`

Replace `OSInterface_*` player calls with `DesktopPlayer.*`:

| Old Call | New Call |
|----------|----------|
| `OSInterface_StartAuto()` | `DesktopPlayer.loadStream()` |
| `OSInterface_stopVideo()` | `DesktopPlayer.stop()` |
| `OSInterface_SetQuality()` | `DesktopPlayer.setQuality()` |
| `OSInterface_getQualities()` | `DesktopPlayer.getQualities()` |
| `OSInterface_mseekTo()` | `DesktopPlayer.seek()` |
| `OSInterface_gettime()` | `DesktopPlayer.getCurrentTime()` |
| `OSInterface_setPlaybackSpeed()` | `DesktopPlayer.setPlaybackSpeed()` |

### 2.4 Features to Implement
- [ ] Quality selection (manual + auto)
- [ ] Low latency mode with catch-up
- [ ] Playback speed (0.25x - 2x)
- [ ] Fast forward/rewind (5s, 30s jumps)
- [ ] Volume control
- [ ] Mute toggle
- [ ] Fullscreen toggle

---

## Phase 3: Code Removal (Android-Specific)

### 3.1 Files to DELETE Entirely
None - we'll modify in place to preserve git history

### 3.2 Functions to REMOVE from OSInterface.js → DesktopInterface.js

**Notification System (Android background service):**
- `OSInterface_StopNotificationService`
- `OSInterface_SetNotificationPosition`
- `OSInterface_SetNotificationRepeat`
- `OSInterface_SetNotificationSinceTime`
- `OSInterface_RunNotificationService`
- `OSInterface_upNotificationState`
- `OSInterface_SetNotificationLive`
- `OSInterface_SetNotificationTitle`
- `OSInterface_SetNotificationGame`

**APK/Update System:**
- `OSInterface_getInstallFromPLay`
- `OSInterface_UpdateAPK`
- `OSInterface_CleanAndLoadUrl`

**Android System:**
- `OSInterface_mhideSystemUI`
- `OSInterface_keyEvent`
- `OSInterface_KeyboardCheckAndHIde`
- `OSInterface_hideKeyboardFrom`
- `OSInterface_isAccessibilitySettingsOn`
- `OSInterface_mKeepScreenOn`
- `OSInterface_AvoidClicks`
- `OSInterface_initbodyClickSet`
- `OSInterface_SetKeysOpacity`
- `OSInterface_SetKeysPosition`

**Android Device Info:**
- `OSInterface_getSDK`
- `OSInterface_deviceIsTV`
- `OSInterface_getcodecCapabilities`
- `OSInterface_setBlackListMediaCodec`
- `OSInterface_setBlackListQualities`
- `OSInterface_getWebviewVersion` (replace with browser UA)

**ExoPlayer Specific:**
- `OSInterface_RestartPlayer`
- `OSInterface_ReuseFeedPlayer`
- `OSInterface_ReuseFeedPlayerPrepare`
- `OSInterface_FixViewPosition`
- `OSInterface_msetPlayer`
- `OSInterface_SetCheckSource`
- `OSInterface_mCheckRefresh`
- `OSInterface_mCheckRefreshToast`
- `OSInterface_getVideoStatus`
- `OSInterface_getVideoQuality`
- `OSInterface_mshowLoading`
- `OSInterface_mshowLoadingBottom`

### 3.3 Update Main.js

Remove/modify:
- APK update check logic (~lines 1160-1320)
- TV detection logic
- Android-specific key mapping
- ExoPlayer status handling

### 3.4 Update Settings.js

Remove settings for:
- Notification service configuration
- ExoPlayer buffer settings
- Codec blacklists
- TV-specific UI options

---

## Phase 4: Desktop Features

### 4.1 In-App Notifications
**File:** `app/specific/Notifications.js` (new)

Overlay notifications when streamers go live:
```javascript
var DesktopNotifications = {
    show: function(message, duration) {
        // Create overlay div above player
        // Auto-dismiss after duration
    },

    showLive: function(channel, game) {
        this.show(`${channel} is now live playing ${game}!`, 5000);
    }
};
```

### 4.2 Tauri Auto-Updater
**Files:** `src-tauri/tauri.conf.json`, `src-tauri/src/lib.rs`

Configure GitHub releases updater:
```json
{
  "plugins": {
    "updater": {
      "active": true,
      "endpoints": [
        "https://github.com/user/repo/releases/latest/download/latest.json"
      ],
      "dialog": true,
      "pubkey": "..."
    }
  }
}
```

### 4.3 Global Hotkeys
**File:** `src-tauri/src/hotkeys.rs` (new)

Media key support:
- Play/Pause: Media Play key or Space
- Volume Up/Down: Media volume keys
- Mute: M key or Media mute

### 4.4 Settings Persistence
Keep using `localStorage` (already works in Tauri WebView)

---

## Phase 5: Multi-Stream & PiP (Future)

### 5.1 Architecture for Multi-Stream
Design player module to support multiple instances:
```javascript
var DesktopPlayer = {
    instances: [],  // Array of player instances

    createInstance: function(containerId) {
        // Create new HLS.js + video element
        // Return instance ID
    },

    destroyInstance: function(instanceId) {
        // Clean up
    }
};
```

### 5.2 PiP Implementation Options
1. **In-window PiP**: Multiple `<video>` elements with CSS positioning
2. **OS-level PiP**: Tauri separate window (more complex)

Recommend: Start with in-window, add OS-level later

---

## File Change Summary

### New Files
| File | Purpose |
|------|---------|
| `app/specific/DesktopInterface.js` | Replaces OSInterface.js |
| `app/specific/PlayDesktop.js` | HLS.js player wrapper |
| `app/specific/Notifications.js` | In-app notifications |
| `src-tauri/src/hotkeys.rs` | Global hotkey handling |
| `src-tauri/src/updater.rs` | Auto-update logic |

### Major Modifications
| File | Changes |
|------|---------|
| `Main.js` | Platform detection, remove APK update, remove TV code |
| `Play.js` | Use DesktopPlayer instead of OSInterface |
| `PlayVod.js` | Use DesktopPlayer |
| `PlayClip.js` | Use DesktopPlayer |
| `PlayHLS.js` | Adapt for HLS.js |
| `PlayEtc.js` | Remove ExoPlayer references |
| `PlayMulti.js` | Prepare for multi-instance |
| `Settings.js` | Remove Android settings |
| `TVKeyValue.js` | Simplify to desktop keys |
| `version.js` | Desktop version info |

### Files to Remove (or gut)
| File | Action |
|------|--------|
| `OSInterface.js` | Replace with DesktopInterface.js |
| `src-tauri/bridge/android-bridge.js` | Delete |

---

## Implementation Order

### Week 1: Foundation
1. [ ] Create DesktopInterface.js skeleton
2. [ ] Add Main_IsDesktop detection
3. [ ] Simplify TVKeyValue.js
4. [ ] Get basic app loading without errors

### Week 2: Player
5. [ ] Integrate HLS.js
6. [ ] Create PlayDesktop.js
7. [ ] Adapt Play.js for desktop
8. [ ] Test single stream playback

### Week 3: Features
9. [ ] Quality selection UI
10. [ ] Playback speed control
11. [ ] Low latency mode
12. [ ] VOD playback (PlayVod.js)

### Week 4: Polish
13. [ ] Remove all Android code paths
14. [ ] In-app notifications
15. [ ] Auto-updater setup
16. [ ] Global hotkeys

### Future
- Multi-stream support
- PiP mode
- Gamepad support

---

## Testing Checklist

### Core Functionality
- [ ] App loads without errors
- [ ] Can browse channels/games
- [ ] Can search
- [ ] Can view channel pages

### Playback
- [ ] Live stream plays
- [ ] Quality selection works
- [ ] Low latency mode works
- [ ] VOD playback works
- [ ] Clips play
- [ ] Seeking works
- [ ] Playback speed works

### UI/Navigation
- [ ] Keyboard navigation works
- [ ] Mouse clicks work
- [ ] Settings save/load
- [ ] Login/auth works

### Desktop Features
- [ ] Window close/minimize
- [ ] Fullscreen toggle
- [ ] Volume control
- [ ] Notifications appear
- [ ] Auto-update check

---

## Dependencies

### JavaScript
- **HLS.js** - HLS streaming (MIT license)

### Rust/Tauri
- **tauri** - Desktop shell
- **tauri-plugin-updater** - Auto-updates
- **tauri-plugin-global-shortcut** - Hotkeys
- **reqwest** - CORS proxy HTTP

---

## Notes

### Why HLS.js?
1. Full quality selection API
2. Low-latency HLS support
3. Hardware acceleration via browser
4. Well-maintained, Twitch-compatible
5. Supports multiple instances (multi-stream ready)

### CORS Strategy
Twitch API requires CORS bypass. Options:
1. **Tauri HTTP commands** - Rust makes requests, returns to JS
2. **Local proxy** - Tauri runs local proxy server

Recommendation: Tauri HTTP commands (simpler, already partially implemented)

### Complete Fork Benefits
- Clean codebase, no Android cruft
- Faster development going forward
- Desktop-optimized UX
- No shim overhead
