# SmartTwitch Desktop - Implementation Plan

## Overview

This document outlines the complete plan to transform SmartTwitchTV from an Android/TV app into a **native Tauri desktop application**. The goal is to **completely remove all Android architecture** and rebuild features natively for desktop with full hardware acceleration support (including NVIDIA RTX Video Super Resolution), proper keyboard/mouse controls, transparent chat overlay, multi-stream support, and native notifications.

**Key Principles:**
- No Android shims or compatibility layers
- Native desktop experience with keyboard/mouse (no TV remote support)
- Hardware-accelerated video with RTX Video SR compatibility
- Full feature parity with Android app, rebuilt natively

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Operating System                              │
├─────────────────────────────────────────────────────────────────────┤
│  NVIDIA Driver (RTX Video SR)  ←── Intercepts decoded video frames  │
│           ↑                                                          │
│  DXVA2 / VideoToolbox / VA-API  ←── Hardware video decode           │
├─────────────────────────────────────────────────────────────────────┤
│                     Tauri + WebView2                                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Rust Backend                                                 │  │
│  │  ├── HTTP proxy (CORS bypass for Twitch/HLS)                  │  │
│  │  ├── Window management (fullscreen, minimize, close)          │  │
│  │  ├── Hardware acceleration control (--disable-gpu flag)       │  │
│  │  ├── Native notifications (tauri-plugin-notification)         │  │
│  │  ├── Clipboard operations                                     │  │
│  │  └── GPU detection (RTX Video hints)                          │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │  JavaScript Frontend                                          │  │
│  │  ├── DesktopPlayer.js      ←── Core HLS.js player             │  │
│  │  ├── DesktopMultiPlayer.js ←── Multi-stream/PiP (4 instances) │  │
│  │  ├── DesktopPreview.js     ←── Hover preview with audio       │  │
│  │  ├── DesktopControls.js    ←── Keyboard/mouse handler         │  │
│  │  ├── DesktopNotifications.js ←── Polling + native notify      │  │
│  │  └── DesktopInterface.js   ←── Minimal Tauri bridge           │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │  Video Elements (hardware-decoded)                            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │  │
│  │  │ Primary  │ │   PiP    │ │ Multi x4 │ │ Preview  │         │  │
│  │  │  Video   │ │  Video   │ │  Videos  │ │  Video   │         │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘         │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Feature Set

### Playback Features
| Feature | Implementation | Status |
|---------|---------------|--------|
| Live Stream Playback | HLS.js with Tauri HTTP proxy | 🔄 Partial |
| VOD Playback | HLS.js with seek support | 🔄 Partial |
| Clip Playback | HLS.js or direct MP4 | 🔄 Partial |
| Quality Selection | HLS.js levels API | 🔄 Partial |
| Auto Quality (ABR) | HLS.js auto level switching | 🔄 Partial |
| Low Latency Mode | HLS.js `lowLatencyMode: true` | ⬜ Not started |
| Latency Catch-Up | Playback rate adjustment | ⬜ Not started |
| Playback Speed | `video.playbackRate` | ⬜ Not started |
| Picture-in-Picture | Second HLS.js instance | ⬜ Not started |
| 50/50 Split View | Two HLS.js instances | ⬜ Not started |
| Quad Multi-Stream | Four HLS.js instances | ⬜ Not started |
| VOD Resume | localStorage position save | ⬜ Not started |
| Hardware Acceleration | WebView2 default + toggle | ⬜ Not started |
| RTX Video SR | Automatic (driver-level) | ⬜ Not started |

### Chat Features
| Feature | Implementation | Status |
|---------|---------------|--------|
| Live Chat (IRC) | Browser WebSocket | ✅ Working |
| VOD Chat | Twitch API replay | ✅ Working |
| Transparent Overlay | CSS with opacity control | ⬜ Not started |
| Position Presets | 6 positions (corners + sides) | ⬜ Not started |
| Width Control | Narrow/Medium/Wide | ⬜ Not started |
| BTTV/FFZ/7TV Emotes | Existing implementation | ✅ Working |

### Controls
| Feature | Implementation | Status |
|---------|---------------|--------|
| Keyboard Shortcuts | DesktopControls.js | ⬜ Not started |
| Mouse Controls | Click/scroll handlers | ⬜ Not started |
| Media Keys | Space, arrows, M, F | ⬜ Not started |
| Native Fullscreen | Tauri window API | ⬜ Not started |

### Desktop Features
| Feature | Implementation | Status |
|---------|---------------|--------|
| Native Notifications | tauri-plugin-notification | ⬜ Not started |
| Live Alert Polling | 60s interval (configurable) | ⬜ Not started |
| Preview on Hover | Lightweight HLS.js + audio | ⬜ Not started |
| Settings Persistence | localStorage | ✅ Working |
| OAuth Login | Device code flow | ✅ Working |

---

## Milestones

### Milestone 1: Video Foundation ✅ COMPLETE
**Goal:** Working single-stream video playback with proper DOM structure

**Deliverables:**
- [x] Video DOM elements in index.html with proper attributes
- [x] player.css with z-index layering and layouts
- [x] Bundled HLS.js v1.5.x in thirdparty/
- [x] Basic DesktopPlayer.js with Tauri HTTP proxy loaders

**Success Criteria:** Can play a Twitch live stream with video visible and controllable

**Files Created/Modified:**
- `app/css/player.css` - Video container layouts, chat overlay, loading states
- `app/thirdparty/hls.min.js` - HLS.js v1.5.7 bundled locally
- `app/specific/DesktopPlayer.js` - Core player module with HLS.js integration
- `app/index.html` - Added video elements, CSS link, script includes

---

### Milestone 2: Hardware Acceleration
**Goal:** GPU-accelerated video with user toggle and RTX Video compatibility

**Deliverables:**
- [ ] Rust startup reads hw_accel setting from app data
- [ ] `--disable-gpu` flag passed to WebView2 when disabled
- [ ] `get_gpu_info` Tauri command for NVIDIA detection
- [ ] Settings UI toggle with restart-required prompt
- [ ] RTX Video hint displayed when NVIDIA GPU detected

**Success Criteria:** Hardware decode working, RTX Video SR activates when enabled in NVIDIA Control Panel

---

### Milestone 3: Desktop Controls
**Goal:** Full keyboard and mouse control of video playback

**Deliverables:**
- [ ] DesktopControls.js with all keyboard shortcuts
- [ ] Mouse click/double-click/scroll handlers
- [ ] Native OS fullscreen via Tauri
- [ ] Volume persistence to localStorage
- [ ] Focus management for keyboard events

**Keyboard Shortcuts:**
| Key | Action |
|-----|--------|
| Space | Play/Pause |
| ← / → | Seek ±10s |
| Shift+← / Shift+→ | Seek ±30s |
| ↑ / ↓ | Volume ±10% |
| M | Mute toggle |
| F | Fullscreen toggle |
| Escape | Exit fullscreen / Close overlay / Back |
| C | Chat visibility toggle |
| Shift+C | Cycle chat position |
| T | Theater mode toggle |
| 1-9 | Quality selection |

**Success Criteria:** All shortcuts working, mouse controls responsive

---

### Milestone 4: Chat Overlay System
**Goal:** Transparent, repositionable chat overlay on video

**Deliverables:**
- [ ] Chat container with configurable opacity (0-100%)
- [ ] 6 position presets (Right, Left, Top-Right, Top-Left, Bottom-Right, Bottom-Left)
- [ ] Width options (Narrow, Medium, Wide)
- [ ] Keyboard shortcut C to toggle, Shift+C to cycle position
- [ ] Settings UI for opacity and position
- [ ] Chat z-index above video, below controls

**Chat Overlay Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Video Player (z-index: 100)              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Stream Video                       │  │
│  │                                       ┌─────────────┐ │  │
│  │                                       │ Chat Overlay│ │  │
│  │                                       │ (z-index:   │ │  │
│  │                                       │  110)       │ │  │
│  │                                       │ Transparent │ │  │
│  │                                       │ Background  │ │  │
│  │                                       └─────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Success Criteria:** Chat overlays video with transparency, position changes work smoothly

---

### Milestone 5: Android Code Removal
**Goal:** Clean codebase with no Android/TV remnants

**Deliverables:**
- [ ] Remove TV remote/D-pad handling from Main.js
- [ ] Delete all `OSInterface_*` shim functions from DesktopInterface.js
- [ ] Remove Android settings from Settings.js (ExoPlayer buffers, codec blacklists)
- [ ] Delete BrowserTest.js
- [ ] Clean language files of Android/TV strings
- [ ] Remove APK update logic
- [ ] Remove notification service stubs

**Success Criteria:** Grep for "Android", "ExoPlayer", "OSInterface_" returns zero results in app code

---

### Milestone 6: Preview Player
**Goal:** Hover preview on channel thumbnails with audio

**Deliverables:**
- [ ] DesktopPreview.js with lightweight HLS.js instance
- [ ] 300ms hover delay before preview starts
- [ ] **Audio enabled** (not muted) - true preview
- [ ] Main player audio paused while preview active
- [ ] 200ms grace period on mouse leave
- [ ] Force low quality (480p) for performance
- [ ] Preview positioned near thumbnail

**Success Criteria:** Hovering over channel shows live preview with audio, smooth transitions

---

### Milestone 7: Multi-Stream & PiP
**Goal:** Watch multiple streams simultaneously

**Deliverables:**
- [ ] DesktopMultiPlayer.js managing up to 4 HLS.js instances
- [ ] PiP mode: Corner overlay (draggable, resizable)
- [ ] 50/50 split: Side-by-side layout
- [ ] Quad view: 2x2 grid
- [ ] Audio focus: Only one stream has audio, click to switch
- [ ] Independent quality per stream
- [ ] Chat switches to focused channel

**Multi-Stream Layouts:**
```
PiP Mode:                  50/50 Mode:              Quad Mode:
┌─────────────────┐       ┌────────┬────────┐      ┌────────┬────────┐
│                 │       │        │        │      │   1    │   2    │
│     Main        │       │   1    │   2    │      ├────────┼────────┤
│            ┌────┤       │        │        │      │   3    │   4    │
│            │PiP │       └────────┴────────┘      └────────┴────────┘
└────────────┴────┘
```

**Success Criteria:** Can watch 2-4 streams simultaneously with audio switching

---

### Milestone 8: Native Notifications
**Goal:** Desktop notifications when followed channels go live

**Deliverables:**
- [ ] Add `tauri-plugin-notification` to Cargo.toml
- [ ] DesktopNotifications.js with polling logic
- [ ] `showLiveNotification(channel, title, game, thumbnail)`
- [ ] `showTitleChange(channel, newTitle)`
- [ ] Configurable polling interval (30s, 60s, 2min, 5min)
- [ ] "Last seen" state to avoid duplicate notifications
- [ ] Click notification → focus app, navigate to channel

**Success Criteria:** Get desktop notification when followed streamer goes live

---

### Milestone 9: Refactor Play*.js
**Goal:** All playback code uses new Desktop modules

**Deliverables:**
- [ ] Play.js → `DesktopPlayer.*` calls
- [ ] PlayVod.js → `DesktopPlayer.*` calls
- [ ] PlayClip.js → `DesktopPlayer.*` calls
- [ ] PlayMulti.js → `DesktopMultiPlayer.*` calls
- [ ] PlayExtra.js → `DesktopMultiPlayer.enablePiP()`
- [ ] UserLiveFeed.js → `DesktopPreview.*` calls
- [ ] Remove all `OSInterface_*` references

**Success Criteria:** Zero `OSInterface_*` calls remaining in playback code

---

## Implementation Order

```
Step 1: Video DOM Infrastructure (Milestone 1)
    ↓
Step 2: Hardware Acceleration (Milestone 2)
    ↓
Step 3: Desktop Player Module (Milestone 1 continued)
    ↓
Step 4: Desktop Controls (Milestone 3)
    ↓
Step 5: Chat Overlay System (Milestone 4)
    ↓
Step 6: Android Code Removal (Milestone 5)
    ↓
Step 7: Preview Player (Milestone 6)
    ↓
Step 8: Multi-Player / PiP (Milestone 7)
    ↓
Step 9: Notifications (Milestone 8)
    ↓
Step 10: Refactor Play*.js (Milestone 9)
```

---

## File Changes Summary

### New Files to Create
| File | Purpose |
|------|---------|
| `app/specific/DesktopPlayer.js` | Core HLS.js single-player module |
| `app/specific/DesktopMultiPlayer.js` | Multi-stream/PiP manager (4 instances) |
| `app/specific/DesktopPreview.js` | Hover preview player with audio |
| `app/specific/DesktopControls.js` | Keyboard/mouse handler |
| `app/specific/DesktopNotifications.js` | Native notification system |
| `app/css/player.css` | Video container layouts, chat overlay |
| `app/thirdparty/hls.min.js` | Bundled HLS.js v1.5.x |

### Files to Rewrite
| File | Changes |
|------|---------|
| `app/specific/DesktopInterface.js` | Remove all shims, keep only Tauri bridge |

### Files to Refactor
| File | Changes |
|------|---------|
| `app/specific/Play.js` | Use DesktopPlayer module |
| `app/specific/PlayVod.js` | Use DesktopPlayer module |
| `app/specific/PlayClip.js` | Use DesktopPlayer module |
| `app/specific/PlayMulti.js` | Use DesktopMultiPlayer module |
| `app/specific/PlayExtra.js` | Use DesktopMultiPlayer.enablePiP |
| `app/specific/Main.js` | Remove TV remote code, simplify platform detection |
| `app/specific/Settings.js` | Add new settings, remove Android settings |
| `app/specific/ChatLive.js` | Add overlay transparency/position support |
| `app/specific/ChatLiveControls.js` | Add position/opacity controls |
| `app/specific/UserLiveFeed.js` | Use DesktopPreview module |
| `app/index.html` | Add video elements, link CSS |

### Files to Delete
| File | Reason |
|------|--------|
| `app/specific/BrowserTest.js` | No longer needed |

### Rust Backend Updates
| File | Changes |
|------|---------|
| `src-tauri/Cargo.toml` | Add tauri-plugin-notification |
| `src-tauri/src/lib.rs` | HW accel flag handling, GPU detection command |
| `src-tauri/tauri.conf.json` | Window config, browser args |

---

## Settings

### New Settings
| Setting | Default | Options | Restart Required |
|---------|---------|---------|------------------|
| Hardware Acceleration | ON | ON/OFF | Yes |
| Chat Overlay Position | Right | Right, Left, Top-Right, Top-Left, Bottom-Right, Bottom-Left | No |
| Chat Overlay Opacity | 80% | 0-100% slider | No |
| Chat Overlay Width | Medium | Narrow, Medium, Wide | No |
| Preview Audio | ON | ON/OFF | No |
| Low Latency Mode | OFF | ON/OFF | No |
| Latency Catch-Up | ON | ON/OFF | No |
| Notification Polling | 60s | 30s, 60s, 2min, 5min | No |

### Settings to Remove (Android-specific)
- ExoPlayer buffer sizes
- Codec blacklists
- Resolution blocking
- TV remote key mapping
- Notification service config
- APK update settings

---

## Dependencies

### JavaScript
| Library | Version | Purpose |
|---------|---------|---------|
| HLS.js | 1.5.x | HLS streaming with custom loaders |

### Rust/Tauri
| Crate | Purpose |
|-------|---------|
| tauri | Desktop shell |
| tauri-plugin-notification | Native notifications |
| reqwest | HTTP proxy for CORS bypass |
| base64 | Binary data encoding for video segments |

---

## Testing Checklist

### Milestone 1-2: Video Foundation
- [ ] Video element visible in DOM
- [ ] HLS.js loads without errors
- [ ] Can play Twitch live stream
- [ ] Video renders (not black screen)
- [ ] Hardware decode active (check GPU usage)

### Milestone 3: Controls
- [ ] Space pauses/plays
- [ ] Arrow keys seek
- [ ] Volume up/down works
- [ ] Mute toggles
- [ ] Fullscreen works (native OS)
- [ ] Mouse click pauses
- [ ] Mouse double-click fullscreens
- [ ] Mouse scroll changes volume

### Milestone 4: Chat Overlay
- [ ] Chat visible over video
- [ ] Transparency adjustable
- [ ] Position changes correctly
- [ ] Width options work
- [ ] Keyboard shortcuts (C, Shift+C) work

### Milestone 5: Code Cleanup
- [ ] No errors in console
- [ ] All features still work
- [ ] No `OSInterface_` references in app/

### Milestone 6: Preview
- [ ] Preview appears on hover
- [ ] Audio plays (not muted)
- [ ] Main player audio pauses
- [ ] Preview destroys on mouse leave
- [ ] Low quality enforced

### Milestone 7: Multi-Stream
- [ ] PiP mode works
- [ ] 50/50 split works
- [ ] Quad view works
- [ ] Audio focus switching works
- [ ] Chat follows focus

### Milestone 8: Notifications
- [ ] Notification appears when channel goes live
- [ ] Click notification focuses app
- [ ] No duplicate notifications
- [ ] Polling interval configurable

### Milestone 9: Final Integration
- [ ] Live stream playback
- [ ] VOD playback with seek
- [ ] Clip playback
- [ ] Quality selection
- [ ] All keyboard shortcuts
- [ ] Settings save/load
- [ ] Login/auth works

---

## Notes

### Why Complete Rewrite Over Shims?
1. **Clean codebase** - No Android cruft or compatibility layers
2. **Better performance** - Direct calls instead of shim overhead
3. **Maintainability** - Easier to debug and extend
4. **Desktop-native UX** - Proper keyboard/mouse patterns

### Hardware Acceleration Strategy
- WebView2 (Windows) has GPU acceleration **enabled by default**
- RTX Video SR works **automatically** at driver level
- User toggle requires app restart (Chromium limitation)
- No code needed for RTX Video - just ensure video plays correctly

### CORS Strategy
All Twitch API and HLS requests go through Tauri's Rust backend:
1. HLS.js custom `pLoader` for playlist requests
2. HLS.js custom `fLoader` for video segment binary data
3. Tauri `invoke()` calls `http_request` / `http_request_binary` commands
4. Rust uses `reqwest` to make actual HTTP requests
5. No CORS issues because requests originate from native code

### Multi-Instance HLS.js
- Each video element gets its own HLS.js instance
- Maximum 4 simultaneous instances (main + PiP or quad)
- Preview uses 5th lightweight instance
- Custom loaders shared across all instances
- Memory managed by destroying unused instances
