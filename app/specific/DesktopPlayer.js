/*
 * SmartTwitch Desktop - Video Player Module
 * 
 * This module manages video playback using HLS.js with Tauri HTTP proxy for CORS bypass.
 * It provides a clean API for the application to control video playback.
 * 
 * Architecture:
 * - DesktopPlayer: Single primary video player
 * - Uses custom HLS.js loaders that route through Tauri backend
 * - All Twitch API/HLS requests bypass CORS via Rust HTTP commands
 */

//=============================================================================
// DESKTOP PLAYER MODULE
//=============================================================================

var DesktopPlayer = {
    // HLS.js instance
    hls: null,
    
    // Video element reference
    video: null,
    
    // Container element reference
    container: null,
    
    // Current stream info
    currentUrl: null,
    currentType: 0, // 0=live, 1=vod, 2=clip
    currentChannel: '',
    
    // Quality management
    qualities: [],
    currentQuality: -1, // -1 = auto
    
    // Playback state
    state: {
        ready: false,
        playing: false,
        paused: false,
        buffering: false,
        ended: false,
        error: null,
        currentTime: 0,
        duration: 0,
        volume: 1,
        muted: false
    },
    
    // Settings
    settings: {
        lowLatency: false,
        catchUp: true,
        targetLatency: 2, // seconds
        maxCatchUpRate: 1.1
    },
    
    // Callbacks
    callbacks: {
        onReady: null,
        onPlay: null,
        onPause: null,
        onBuffer: null,
        onEnded: null,
        onError: null,
        onQualityChange: null,
        onTimeUpdate: null
    }
};

//=============================================================================
// INITIALIZATION
//=============================================================================

/**
 * Initialize the player with DOM elements
 * @returns {boolean} Success status
 */
DesktopPlayer.init = function() {
    // Get video element
    this.video = document.getElementById('player_video');
    this.container = document.getElementById('player_video_container');
    
    if (!this.video) {
        console.error('[DesktopPlayer] Video element #player_video not found');
        return false;
    }
    
    if (!this.container) {
        console.error('[DesktopPlayer] Container element #player_video_container not found');
        return false;
    }
    
    // Setup video element event listeners
    this._setupVideoEvents();
    
    // Load saved volume
    this._loadVolumeSettings();
    
    console.log('[DesktopPlayer] Initialized');
    return true;
};

/**
 * Check if HLS.js is available and supported
 * @returns {boolean}
 */
DesktopPlayer.isSupported = function() {
    return typeof Hls !== 'undefined' && Hls.isSupported();
};

//=============================================================================
// VIDEO EVENT HANDLERS
//=============================================================================

DesktopPlayer._setupVideoEvents = function() {
    var self = this;
    var video = this.video;
    
    video.addEventListener('loadedmetadata', function() {
        self.state.duration = video.duration * 1000;
        console.log('[DesktopPlayer] Metadata loaded, duration:', self.state.duration);
    });
    
    video.addEventListener('playing', function() {
        self.state.playing = true;
        self.state.paused = false;
        self.state.buffering = false;
        self._hideLoading();
        if (self.callbacks.onPlay) self.callbacks.onPlay();
    });
    
    video.addEventListener('pause', function() {
        self.state.playing = false;
        self.state.paused = true;
        if (self.callbacks.onPause) self.callbacks.onPause();
    });
    
    video.addEventListener('waiting', function() {
        self.state.buffering = true;
        self._showLoading();
        if (self.callbacks.onBuffer) self.callbacks.onBuffer(true);
    });
    
    video.addEventListener('canplay', function() {
        self.state.buffering = false;
        self._hideLoading();
        if (self.callbacks.onBuffer) self.callbacks.onBuffer(false);
    });
    
    video.addEventListener('ended', function() {
        self.state.playing = false;
        self.state.ended = true;
        if (self.callbacks.onEnded) self.callbacks.onEnded();
    });
    
    video.addEventListener('error', function(e) {
        self.state.error = e;
        console.error('[DesktopPlayer] Video error:', e);
        if (self.callbacks.onError) self.callbacks.onError(e);
    });
    
    video.addEventListener('timeupdate', function() {
        self.state.currentTime = Math.floor(video.currentTime * 1000);
        if (self.callbacks.onTimeUpdate) {
            self.callbacks.onTimeUpdate(self.state.currentTime, self.state.duration);
        }
        
        // Low latency catch-up
        if (self.settings.lowLatency && self.settings.catchUp && self.currentType === 0) {
            self._handleLatencyCatchUp();
        }
    });
    
    video.addEventListener('volumechange', function() {
        self.state.volume = video.volume;
        self.state.muted = video.muted;
        self._saveVolumeSettings();
    });
};

//=============================================================================
// HLS.JS CUSTOM LOADERS
//=============================================================================

/**
 * Create custom playlist loader for HLS.js
 * Routes m3u8 requests through Tauri backend
 */
DesktopPlayer._createPlaylistLoader = function() {
    function TauriPlaylistLoader(config) {
        this.config = config;
        this.stats = {
            aborted: false,
            loaded: 0,
            retry: 0,
            total: 0,
            chunkCount: 0,
            bwEstimate: 0,
            loading: { start: 0, first: 0, end: 0 },
            parsing: { start: 0, end: 0 },
            buffering: { start: 0, first: 0, end: 0 }
        };
    }
    
    TauriPlaylistLoader.prototype.load = function(context, config, callbacks) {
        var self = this;
        var url = context.url;
        
        self.stats.loading.start = performance.now();
        
        // Handle blob URLs directly (no CORS issues)
        if (url.indexOf('blob:') === 0) {
            fetch(url)
                .then(function(response) { return response.text(); })
                .then(function(text) {
                    if (self.stats.aborted) return;
                    self.stats.loading.first = self.stats.loading.end = performance.now();
                    self.stats.loaded = self.stats.total = text.length;
                    callbacks.onSuccess({ url: url, data: text }, self.stats, context, null);
                })
                .catch(function(e) {
                    if (!self.stats.aborted) {
                        callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
                    }
                });
            return;
        }
        
        // Route through Tauri for CORS bypass
        Desktop_invoke('base_xml_http_get', {
            urlString: url,
            timeout: config.timeout || 20000,
            postMessage: null,
            method: 'GET',
            jsonHeadersArray: null
        }).then(function(response) {
            if (self.stats.aborted) return;
            
            self.stats.loading.first = self.stats.loading.end = performance.now();
            
            if (response && response.status === 200 && response.response_text) {
                self.stats.loaded = self.stats.total = response.response_text.length;
                callbacks.onSuccess({
                    url: url,
                    data: response.response_text
                }, self.stats, context, null);
            } else {
                callbacks.onError({
                    code: response ? response.status : 0,
                    text: 'HTTP Error ' + (response ? response.status : 'unknown')
                }, context, null, self.stats);
            }
        }).catch(function(e) {
            if (!self.stats.aborted) {
                console.error('[DesktopPlayer] Playlist load error:', e);
                callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
            }
        });
    };
    
    TauriPlaylistLoader.prototype.abort = function() {
        this.stats.aborted = true;
    };
    
    TauriPlaylistLoader.prototype.destroy = function() {
        this.abort();
    };
    
    return TauriPlaylistLoader;
};

/**
 * Create custom fragment loader for HLS.js
 * Routes video segment requests through Tauri backend (binary data)
 */
DesktopPlayer._createFragmentLoader = function() {
    function TauriFragmentLoader(config) {
        this.config = config;
        this.stats = {
            aborted: false,
            loaded: 0,
            retry: 0,
            total: 0,
            chunkCount: 0,
            bwEstimate: 0,
            loading: { start: 0, first: 0, end: 0 },
            parsing: { start: 0, end: 0 },
            buffering: { start: 0, first: 0, end: 0 }
        };
    }
    
    TauriFragmentLoader.prototype.load = function(context, config, callbacks) {
        var self = this;
        var url = context.url;
        
        self.stats.loading.start = performance.now();
        
        // Use Tauri binary fetch for video segments
        Desktop_invoke('fetch_binary', {
            url: url,
            timeout: config.timeout || 30000
        }).then(function(response) {
            if (self.stats.aborted) return;
            
            self.stats.loading.first = self.stats.loading.end = performance.now();
            
            if (response && response.status === 200 && response.data) {
                // Convert byte array to Uint8Array
                var uint8Array = new Uint8Array(response.data);
                self.stats.loaded = self.stats.total = uint8Array.length;
                
                callbacks.onSuccess({
                    url: url,
                    data: uint8Array.buffer
                }, self.stats, context, null);
            } else {
                callbacks.onError({
                    code: response ? response.status : 0,
                    text: 'HTTP Error'
                }, context, null, self.stats);
            }
        }).catch(function(e) {
            if (!self.stats.aborted) {
                console.error('[DesktopPlayer] Fragment load error:', e);
                callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
            }
        });
    };
    
    TauriFragmentLoader.prototype.abort = function() {
        this.stats.aborted = true;
    };
    
    TauriFragmentLoader.prototype.destroy = function() {
        this.abort();
    };
    
    return TauriFragmentLoader;
};

//=============================================================================
// HLS.JS INSTANCE MANAGEMENT
//=============================================================================

/**
 * Create and configure HLS.js instance
 */
DesktopPlayer._createHLSInstance = function() {
    if (this.hls) {
        this._destroyHLSInstance();
    }
    
    if (!this.isSupported()) {
        console.error('[DesktopPlayer] HLS.js not supported');
        return null;
    }
    
    var self = this;
    var isLive = this.currentType === 0;
    
    this.hls = new Hls({
        debug: false,
        enableWorker: true,
        lowLatencyMode: isLive && this.settings.lowLatency,
        backBufferLength: isLive ? 30 : 90,
        maxBufferLength: isLive ? 10 : 30,
        maxMaxBufferLength: isLive ? 30 : 600,
        maxBufferSize: 60 * 1000 * 1000, // 60MB
        maxBufferHole: 0.5,
        startLevel: -1, // Auto quality
        capLevelToPlayerSize: false,
        progressive: false, // Better for hardware decode
        
        // Custom loaders for CORS bypass
        pLoader: this._createPlaylistLoader(),
        fLoader: this._createFragmentLoader(),
        
        // Timeouts
        manifestLoadingTimeOut: 10000,
        manifestLoadingMaxRetry: 3,
        levelLoadingTimeOut: 10000,
        levelLoadingMaxRetry: 3,
        fragLoadingTimeOut: 20000,
        fragLoadingMaxRetry: 6
    });
    
    // Event handlers
    this.hls.on(Hls.Events.MANIFEST_PARSED, function(event, data) {
        self._onManifestParsed(data);
    });
    
    this.hls.on(Hls.Events.LEVEL_SWITCHED, function(event, data) {
        self._onLevelSwitched(data);
    });
    
    this.hls.on(Hls.Events.ERROR, function(event, data) {
        self._onHLSError(data);
    });
    
    this.hls.on(Hls.Events.FRAG_BUFFERED, function() {
        self.state.buffering = false;
        self._hideLoading();
    });
    
    console.log('[DesktopPlayer] HLS.js instance created');
    return this.hls;
};

/**
 * Destroy HLS.js instance and clean up
 */
DesktopPlayer._destroyHLSInstance = function() {
    if (this.hls) {
        this.hls.destroy();
        this.hls = null;
    }
    this.qualities = [];
    this.currentQuality = -1;
    this.state.ready = false;
};

//=============================================================================
// HLS EVENT HANDLERS
//=============================================================================

DesktopPlayer._onManifestParsed = function(data) {
    console.log('[DesktopPlayer] Manifest parsed, levels:', data.levels.length);
    
    // Build quality list
    this.qualities = [];
    for (var i = 0; i < data.levels.length; i++) {
        var level = data.levels[i];
        this.qualities.push({
            index: i,
            id: this._getQualityName(level),
            bitrate: level.bitrate || 0,
            width: level.width || 0,
            height: level.height || 0,
            codec: level.videoCodec || 'avc',
            frameRate: level.frameRate || 30
        });
    }
    
    this.state.ready = true;
    
    // Notify ready
    if (this.callbacks.onReady) {
        this.callbacks.onReady(this.qualities);
    }
    
    // Start playback
    this.video.play().catch(function(e) {
        console.warn('[DesktopPlayer] Autoplay blocked:', e);
    });
};

DesktopPlayer._onLevelSwitched = function(data) {
    this.currentQuality = data.level;
    console.log('[DesktopPlayer] Quality switched to level', data.level);
    
    if (this.callbacks.onQualityChange) {
        this.callbacks.onQualityChange(data.level, this.qualities[data.level]);
    }
};

DesktopPlayer._onHLSError = function(data) {
    console.error('[DesktopPlayer] HLS error:', data.type, data.details);
    
    if (data.fatal) {
        switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
                console.log('[DesktopPlayer] Network error, attempting recovery...');
                this.hls.startLoad();
                break;
            case Hls.ErrorTypes.MEDIA_ERROR:
                console.log('[DesktopPlayer] Media error, attempting recovery...');
                this.hls.recoverMediaError();
                break;
            default:
                console.error('[DesktopPlayer] Fatal error, cannot recover');
                this.state.error = data;
                if (this.callbacks.onError) {
                    this.callbacks.onError(data);
                }
                break;
        }
    }
};

DesktopPlayer._getQualityName = function(level) {
    if (!level.height) {
        return level.bitrate ? Math.round(level.bitrate / 1000) + 'kbps' : 'Source';
    }
    var name = level.height + 'p';
    if (level.frameRate && level.frameRate >= 50) {
        name += Math.round(level.frameRate);
    }
    return name;
};

//=============================================================================
// PLAYBACK CONTROL
//=============================================================================

/**
 * Play an HLS stream
 * @param {string} url - HLS manifest URL
 * @param {string} manifestContent - Optional pre-fetched manifest content
 * @param {number} type - Stream type (0=live, 1=vod, 2=clip)
 * @param {number} resumePosition - Position to resume from (ms)
 * @param {string} channel - Channel name
 */
DesktopPlayer.playHLS = function(url, manifestContent, type, resumePosition, channel) {
    var self = this;
    
    console.log('[DesktopPlayer] playHLS called:', {
        url: url ? url.substring(0, 80) + '...' : 'null',
        type: type,
        resumePosition: resumePosition,
        channel: channel
    });
    
    // Ensure initialized
    if (!this.video && !this.init()) {
        console.error('[DesktopPlayer] Failed to initialize');
        return;
    }
    
    // Stop any current playback
    this.stop();
    
    // Store stream info
    this.currentUrl = url;
    this.currentType = type || 0;
    this.currentChannel = channel || '';
    
    // Reset state
    this.state = {
        ready: false,
        playing: false,
        paused: false,
        buffering: true,
        ended: false,
        error: null,
        currentTime: 0,
        duration: 0,
        volume: this.video.volume,
        muted: this.video.muted
    };
    
    // Show container and loading
    this.show();
    this._showLoading();
    
    // Create HLS instance
    if (!this._createHLSInstance()) {
        console.error('[DesktopPlayer] Failed to create HLS instance');
        return;
    }
    
    // Attach to video element
    this.hls.attachMedia(this.video);
    
    // Load source
    if (manifestContent && manifestContent.length > 0) {
        // Use blob URL for pre-fetched manifest
        var blob = new Blob([manifestContent], { type: 'application/vnd.apple.mpegurl' });
        var blobUrl = URL.createObjectURL(blob);
        this.hls.loadSource(blobUrl);
        
        // Clean up blob URL after load
        setTimeout(function() {
            URL.revokeObjectURL(blobUrl);
        }, 30000);
    } else {
        this.hls.loadSource(url);
    }
    
    // Handle resume position for VODs
    if (resumePosition > 0 && type === 1) {
        this.hls.once(Hls.Events.MANIFEST_PARSED, function() {
            setTimeout(function() {
                self.seek(resumePosition);
            }, 500);
        });
    }
};

/**
 * Stop playback and clean up
 */
DesktopPlayer.stop = function() {
    this._destroyHLSInstance();
    
    if (this.video) {
        this.video.pause();
        this.video.removeAttribute('src');
        this.video.load();
    }
    
    this.hide();
    this._hideLoading();
    
    this.currentUrl = null;
    this.currentChannel = '';
    
    this.state = {
        ready: false,
        playing: false,
        paused: false,
        buffering: false,
        ended: false,
        error: null,
        currentTime: 0,
        duration: 0,
        volume: this.state.volume,
        muted: this.state.muted
    };
    
    console.log('[DesktopPlayer] Stopped');
};

/**
 * Play (resume) playback
 */
DesktopPlayer.play = function() {
    if (this.video) {
        this.video.play().catch(function(e) {
            console.warn('[DesktopPlayer] Play failed:', e);
        });
    }
};

/**
 * Pause playback
 */
DesktopPlayer.pause = function() {
    if (this.video) {
        this.video.pause();
    }
};

/**
 * Toggle play/pause
 */
DesktopPlayer.togglePlayPause = function() {
    if (this.video) {
        if (this.video.paused) {
            this.play();
        } else {
            this.pause();
        }
    }
};

/**
 * Seek to position
 * @param {number} positionMs - Position in milliseconds
 */
DesktopPlayer.seek = function(positionMs) {
    if (this.video && !isNaN(positionMs)) {
        this.video.currentTime = positionMs / 1000;
    }
};

/**
 * Seek relative to current position
 * @param {number} deltaMs - Delta in milliseconds (positive = forward)
 */
DesktopPlayer.seekRelative = function(deltaMs) {
    if (this.video) {
        this.video.currentTime += deltaMs / 1000;
    }
};

//=============================================================================
// QUALITY CONTROL
//=============================================================================

/**
 * Set quality level
 * @param {number} index - Quality index (-1 for auto)
 */
DesktopPlayer.setQuality = function(index) {
    if (this.hls) {
        this.hls.currentLevel = index;
        this.currentQuality = index;
    }
};

/**
 * Get available qualities
 * @returns {Array} Quality levels
 */
DesktopPlayer.getQualities = function() {
    return this.qualities;
};

/**
 * Get current quality index
 * @returns {number} Current quality index (-1 for auto)
 */
DesktopPlayer.getCurrentQuality = function() {
    return this.currentQuality;
};

//=============================================================================
// VOLUME CONTROL
//=============================================================================

/**
 * Set volume
 * @param {number} volume - Volume level (0-1)
 */
DesktopPlayer.setVolume = function(volume) {
    if (this.video) {
        this.video.volume = Math.max(0, Math.min(1, volume));
    }
};

/**
 * Get current volume
 * @returns {number} Volume level (0-1)
 */
DesktopPlayer.getVolume = function() {
    return this.video ? this.video.volume : 1;
};

/**
 * Set muted state
 * @param {boolean} muted
 */
DesktopPlayer.setMuted = function(muted) {
    if (this.video) {
        this.video.muted = muted;
    }
};

/**
 * Check if muted
 * @returns {boolean}
 */
DesktopPlayer.isMuted = function() {
    return this.video ? this.video.muted : false;
};

/**
 * Toggle mute
 */
DesktopPlayer.toggleMute = function() {
    if (this.video) {
        this.video.muted = !this.video.muted;
    }
};

DesktopPlayer._loadVolumeSettings = function() {
    try {
        var savedVolume = localStorage.getItem('DesktopPlayer_volume');
        var savedMuted = localStorage.getItem('DesktopPlayer_muted');
        
        if (savedVolume !== null && this.video) {
            this.video.volume = parseFloat(savedVolume);
        }
        if (savedMuted !== null && this.video) {
            this.video.muted = savedMuted === 'true';
        }
    } catch (e) {
        console.warn('[DesktopPlayer] Failed to load volume settings:', e);
    }
};

DesktopPlayer._saveVolumeSettings = function() {
    try {
        localStorage.setItem('DesktopPlayer_volume', this.video.volume);
        localStorage.setItem('DesktopPlayer_muted', this.video.muted);
    } catch (e) {
        console.warn('[DesktopPlayer] Failed to save volume settings:', e);
    }
};

//=============================================================================
// PLAYBACK INFO
//=============================================================================

/**
 * Get current time in milliseconds
 * @returns {number}
 */
DesktopPlayer.getCurrentTime = function() {
    return this.video ? Math.floor(this.video.currentTime * 1000) : 0;
};

/**
 * Get duration in milliseconds
 * @returns {number}
 */
DesktopPlayer.getDuration = function() {
    return this.video ? Math.floor(this.video.duration * 1000) : 0;
};

/**
 * Check if playing
 * @returns {boolean}
 */
DesktopPlayer.isPlaying = function() {
    return this.video ? !this.video.paused : false;
};

/**
 * Get current latency (live streams)
 * @returns {number} Latency in seconds
 */
DesktopPlayer.getLatency = function() {
    if (this.hls && this.hls.latency !== undefined) {
        return this.hls.latency;
    }
    return 0;
};

/**
 * Get playback state code
 * @returns {number} State code (-1=error, 1=playing, 2=buffering, 3=paused, 4=ended)
 */
DesktopPlayer.getStateCode = function() {
    if (this.state.error) return -1;
    if (this.state.ended) return 4;
    if (this.state.buffering) return 2;
    if (this.state.playing) return 1;
    return 3; // Paused/idle
};

//=============================================================================
// VISIBILITY CONTROL
//=============================================================================

/**
 * Show the video container
 */
DesktopPlayer.show = function() {
    if (this.container) {
        this.container.classList.add('active');
    }
};

/**
 * Hide the video container
 */
DesktopPlayer.hide = function() {
    if (this.container) {
        this.container.classList.remove('active');
    }
};

/**
 * Check if visible
 * @returns {boolean}
 */
DesktopPlayer.isVisible = function() {
    return this.container ? this.container.classList.contains('active') : false;
};

DesktopPlayer._showLoading = function() {
    var overlay = document.getElementById('player_loading_overlay');
    if (overlay) {
        overlay.classList.add('visible');
    }
};

DesktopPlayer._hideLoading = function() {
    var overlay = document.getElementById('player_loading_overlay');
    if (overlay) {
        overlay.classList.remove('visible');
    }
};

//=============================================================================
// LOW LATENCY CATCH-UP
//=============================================================================

DesktopPlayer._handleLatencyCatchUp = function() {
    if (!this.hls || this.currentType !== 0) return;
    
    var latency = this.getLatency();
    var target = this.settings.targetLatency;
    
    if (latency > target + 1) {
        // We're behind, speed up playback
        var catchUpRate = Math.min(this.settings.maxCatchUpRate, 1 + (latency - target) * 0.05);
        if (this.video.playbackRate !== catchUpRate) {
            this.video.playbackRate = catchUpRate;
        }
    } else if (this.video.playbackRate !== 1) {
        // We're caught up, return to normal speed
        this.video.playbackRate = 1;
    }
};

//=============================================================================
// GPU/RTX DETECTION
//=============================================================================

/**
 * Detect GPU information for RTX Video hints
 * @returns {Object} GPU info
 */
DesktopPlayer.detectGPU = function() {
    var result = {
        vendor: 'unknown',
        renderer: 'unknown',
        isNvidia: false,
        supportsRTXVideo: false
    };
    
    try {
        var canvas = document.createElement('canvas');
        var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
        
        if (gl) {
            var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
            if (debugInfo) {
                result.vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
                result.renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
                result.isNvidia = result.renderer.toLowerCase().indexOf('nvidia') !== -1;
                
                // RTX Video is available on RTX GPUs (20-series and newer)
                if (result.isNvidia) {
                    var rtxMatch = result.renderer.match(/RTX\s*(\d+)/i);
                    if (rtxMatch) {
                        result.supportsRTXVideo = true;
                    }
                }
            }
        }
    } catch (e) {
        console.warn('[DesktopPlayer] GPU detection failed:', e);
    }
    
    return result;
};

//=============================================================================
// INITIALIZATION ON DOM READY
//=============================================================================

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        DesktopPlayer.init();
    });
} else {
    // DOM already ready
    setTimeout(function() {
        DesktopPlayer.init();
    }, 0);
}
