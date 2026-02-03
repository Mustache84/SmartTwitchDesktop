/*
 * Copyright (c) 2017-present Felipe de Leon <fglfgl27@gmail.com>
 * Desktop fork maintained separately
 *
 * This file is part of SmartTwitchTV Desktop
 *
 * SmartTwitchTV is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * SmartTwitchTV is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with SmartTwitchTV.  If not, see <https://github.com/fgl27/SmartTwitchTV/blob/master/LICENSE>.
 *
 */

// DesktopInterface.js - Clean desktop implementation replacing OSInterface.js
// This file provides native desktop functionality via Tauri and browser APIs
// All Android-specific code has been removed

//=============================================================================
// PLATFORM DETECTION
//=============================================================================

var Main_IsDesktop = window.__TAURI__ !== undefined || window.__TAURI_INTERNALS__ !== undefined;
var Desktop_Version = 'Desktop-1.0.0';

//=============================================================================
// TAURI IPC HELPERS
//=============================================================================

function Desktop_getInvoke() {
    if (window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke) {
        return window.__TAURI_INTERNALS__.invoke;
    }
    if (window.__TAURI__ && window.__TAURI__.core && window.__TAURI__.core.invoke) {
        return window.__TAURI__.core.invoke;
    }
    return null;
}

function Desktop_invoke(cmd, args) {
    var invoke = Desktop_getInvoke();
    if (invoke) {
        return invoke(cmd, args);
    }
    return Promise.reject('Tauri not available');
}

//=============================================================================
// VERSION & DETECTION FUNCTIONS
//=============================================================================

function OSInterface_getversion() {
    if (window.__TAURI_BRIDGE_VERSION__) {
        return window.__TAURI_BRIDGE_VERSION__;
    }
    return Desktop_Version;
}

function OSInterface_getdebug() {
    return window.__TAURI_BRIDGE_DEBUG__ || false;
}

function OSInterface_getDevice() {
    return window.__TAURI_BRIDGE_DEVICE__ || 'Desktop';
}

function OSInterface_getManufacturer() {
    return 'Tauri Desktop';
}

function OSInterface_getSDK() {
    return 99; // High value indicates desktop
}

function OSInterface_deviceIsTV() {
    return false;
}

function OSInterface_getWebviewVersion() {
    return navigator.userAgent;
}

function OSInterface_mPageUrl() {
    return window.location.href;
}

//=============================================================================
// HTTP FUNCTIONS (Using Tauri for CORS bypass)
//=============================================================================

// Cache for sync HTTP results (workaround for async Tauri)
var Desktop_HttpCache = {};
var Desktop_HttpPending = {};

// Synchronous HTTP request - uses Tauri backend for CORS bypass
// Note: Uses async under the hood with caching for subsequent calls
function OSInterface_mMethodUrlHeaders(urlString, timeout, postMessage, Method, checkResult, JsonHeadersArray) {
    var method = Method || 'GET';
    var body = postMessage;

    // Handle case where postMessage is actually the HTTP method
    if (!Method && postMessage && ['POST', 'PUT', 'DELETE', 'PATCH'].indexOf(postMessage.toUpperCase()) !== -1) {
        method = postMessage.toUpperCase();
        body = null;
    }

    // Create cache key
    var cacheKey = urlString + '|' + method + '|' + (body || '') + '|' + (JsonHeadersArray || '');

    // Check cache first
    if (Desktop_HttpCache[cacheKey] !== undefined) {
        var cached = Desktop_HttpCache[cacheKey];
        delete Desktop_HttpCache[cacheKey]; // One-time use
        return cached;
    }

    // Start async request for future use
    if (!Desktop_HttpPending[cacheKey]) {
        Desktop_HttpPending[cacheKey] = true;
        Desktop_invoke('m_method_url_headers', {
            urlString: urlString,
            timeout: timeout || 10000,
            postMessage: body || null,
            method: method,
            checkResult: checkResult || 0,
            jsonHeadersArray: JsonHeadersArray || null
        }).then(function(result) {
            Desktop_HttpCache[cacheKey] = result;
            delete Desktop_HttpPending[cacheKey];
        }).catch(function(e) {
            console.error('[DesktopInterface] mMethodUrlHeaders async error:', e);
            Desktop_HttpCache[cacheKey] = null;
            delete Desktop_HttpPending[cacheKey];
        });
    }

    // Fallback: Try sync XHR (may fail due to CORS but works for same-origin)
    try {
        var xhr = new XMLHttpRequest();
        xhr.open(method, urlString, false);

        if (JsonHeadersArray) {
            try {
                var headers = JSON.parse(JsonHeadersArray);
                for (var i = 0; i < headers.length; i++) {
                    if (headers[i] && headers[i].length >= 2) {
                        xhr.setRequestHeader(headers[i][0], headers[i][1]);
                    }
                }
            } catch (e) {
                // Ignore header parse errors
            }
        }

        if (body && method !== 'GET') {
            xhr.send(body);
        } else {
            xhr.send(null);
        }

        return xhr.responseText;
    } catch (e) {
        // XHR failed (likely CORS), return null - async result will be cached for retry
        console.log('[DesktopInterface] Sync XHR failed, async request pending:', urlString.substring(0, 50));
        return null;
    }
}

// Async HTTP request with callbacks - Rust returns response, JS handles callbacks
function OSInterface_BaseXmlHttpGet(urlString, timeout, postMessage, Method, JsonHeadersArray, callback, checkResult, key, callBackSuccess, calBackError) {
    console.log('[DesktopInterface] BaseXmlHttpGet called:', {
        url: urlString ? urlString.substring(0, 80) : 'null',
        callback: callback,
        callBackSuccess: callBackSuccess
    });

    Desktop_invoke('base_xml_http_get', {
        urlString: urlString,
        timeout: timeout || 10000,
        postMessage: postMessage || null,
        method: Method || 'GET',
        jsonHeadersArray: JsonHeadersArray || null
    }).then(function(response) {
        console.log('[DesktopInterface] BaseXmlHttpGet response:', {
            status: response ? response.status : 'null',
            hasResponseText: response ? !!response.response_text : false,
            responseTextLength: response && response.response_text ? response.response_text.length : 0
        });
        // Invoke the callback function with the response
        // Format response as JSON string with status, responseText, url, and checkResult
        // url is needed by Play_loadDataResultEnd to set Play_data.AutoUrl
        // checkResult is needed by Play_loadDataResult for request validation
        if (callback && typeof window[callback] === 'function') {
            try {
                var wrappedResponse = JSON.stringify({
                    status: response ? response.status : 0,
                    responseText: response ? response.response_text : '',
                    url: urlString,
                    checkResult: checkResult || 0
                });
                console.log('[DesktopInterface] Invoking callback:', callback);
                window[callback](wrappedResponse, key || 0, callBackSuccess, calBackError, checkResult || 0);
            } catch (cbError) {
                console.error('[DesktopInterface] Callback error:', cbError);
            }
        } else {
            console.error('[DesktopInterface] Callback not found:', callback);
        }
    }).catch(function(e) {
        console.error('[DesktopInterface] BaseXmlHttpGet error:', e);
        if (callback && typeof window[callback] === 'function') {
            try {
                window[callback](null, key || 0, callBackSuccess, calBackError, checkResult || 0);
            } catch (cbError) {
                console.error('[DesktopInterface] Error callback failed:', cbError);
            }
        }
    });
}

// Full async HTTP request with validation - Rust returns response, JS handles callbacks
function OSInterface_XmlHttpGetFull(urlString, timeout, postMessage, Method, JsonHeadersArray, callback, checkResult, check_1, check_2, check_3, check_4, check_5, callBackSuccess, callBackError) {
    console.log('[DesktopInterface] XmlHttpGetFull called:', {
        url: urlString ? urlString.substring(0, 80) : 'null',
        callback: callback,
        checkResult: checkResult,
        callBackSuccess: callBackSuccess
    });

    Desktop_invoke('xml_http_get_full', {
        urlString: urlString,
        timeout: timeout || 10000,
        postMessage: postMessage || null,
        method: Method || 'GET',
        jsonHeadersArray: JsonHeadersArray || null
    }).then(function(response) {
        console.log('[DesktopInterface] XmlHttpGetFull response:', {
            status: response ? response.status : 'null',
            hasResponseText: response ? !!response.response_text : false,
            responseTextLength: response && response.response_text ? response.response_text.length : 0
        });
        // Invoke the callback function with the response
        // Format response as JSON string with status, responseText, url, and checkResult
        // url is needed by Play_loadDataResultEnd to set Play_data.AutoUrl
        // checkResult is needed by Play_loadDataResult for request validation
        if (callback && typeof window[callback] === 'function') {
            try {
                var wrappedResponse = JSON.stringify({
                    status: response ? response.status : 0,
                    responseText: response ? response.response_text : '',
                    url: urlString,
                    checkResult: checkResult || 0
                });
                console.log('[DesktopInterface] Invoking callback:', callback, 'with checkResult:', checkResult);
                window[callback](wrappedResponse, checkResult || 0, check_1 || null, check_2 || null, check_3 || null, check_4 || null, check_5 || null, callBackSuccess, callBackError);
            } catch (cbError) {
                console.error('[DesktopInterface] Callback error:', cbError);
            }
        } else {
            console.error('[DesktopInterface] Callback not found:', callback);
        }
    }).catch(function(e) {
        console.error('[DesktopInterface] XmlHttpGetFull error:', e);
        if (callBackError && typeof window[callBackError] === 'function') {
            try {
                window[callBackError](null);
            } catch (cbError) {
                console.error('[DesktopInterface] Error callback failed:', cbError);
            }
        }
    });
}

//=============================================================================
// CLIPBOARD FUNCTIONS (Using browser API)
//=============================================================================

function OSInterface_mwritetoclipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).catch(function(e) {
            console.error('[DesktopInterface] Clipboard write error:', e);
        });
    }
}

function OSInterface_mreadclipboard() {
    // Note: Clipboard read is async, return empty for sync compatibility
    // The app should be updated to use async clipboard API
    return '';
}

//=============================================================================
// WINDOW FUNCTIONS (Using Tauri window API)
//=============================================================================

function OSInterface_mclose(close) {
    Desktop_invoke('mclose', { close: Boolean(close) }).catch(function(e) {
        console.error('[DesktopInterface] mclose error:', e);
    });
}

function OSInterface_mloadUrl(url) {
    window.location.href = url;
}

//=============================================================================
// HLS.JS CUSTOM LOADER
// Routes HLS.js HTTP requests through Tauri backend to bypass CORS
//=============================================================================

// Custom loader class for HLS.js that uses Tauri for HTTP requests
// This bypasses CORS restrictions by routing through the Rust backend
var Desktop_HLSLoader = function(config) {
    var self = this;
    self.stats = {
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
    self.context = null;
    self.callbacks = null;
    self.retryDelay = 0;
};

Desktop_HLSLoader.prototype.load = function(context, config, callbacks) {
    var self = this;
    self.context = context;
    self.callbacks = callbacks;
    self.stats.loading.start = performance.now();
    self.retryDelay = config.retryDelay || 0;

    var url = context.url;

    console.log('[HLSLoader] Loading playlist:', url.substring(0, 100) + '...');

    // Handle blob URLs directly using native fetch (no CORS issues for local blobs)
    if (url.indexOf('blob:') === 0) {
        console.log('[HLSLoader] Blob URL detected, using native fetch');
        fetch(url)
            .then(function(response) {
                return response.text();
            })
            .then(function(text) {
                if (self.stats.aborted) {
                    console.log('[HLSLoader] Request aborted');
                    return;
                }
                self.stats.loading.first = performance.now();
                self.stats.loading.end = performance.now();
                self.stats.loaded = text.length;
                self.stats.total = text.length;
                console.log('[HLSLoader] Blob loaded, size:', text.length);
                callbacks.onSuccess({
                    url: url,
                    data: text
                }, self.stats, context, null);
            })
            .catch(function(e) {
                if (self.stats.aborted) {
                    return;
                }
                console.error('[HLSLoader] Blob load error:', e);
                callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
            });
        return;
    }

    // For regular URLs, use Tauri backend to bypass CORS
    Desktop_invoke('base_xml_http_get', {
        urlString: url,
        timeout: config.timeout || 20000,
        postMessage: null,
        method: 'GET',
        jsonHeadersArray: null
    }).then(function(response) {
        if (self.stats.aborted) {
            console.log('[HLSLoader] Request aborted');
            return;
        }

        self.stats.loading.first = performance.now();
        self.stats.loading.end = performance.now();

        console.log('[HLSLoader] Response status:', response ? response.status : 'null');

        if (response && response.status === 200 && response.response_text) {
            self.stats.loaded = response.response_text.length;
            self.stats.total = response.response_text.length;

            console.log('[HLSLoader] Success, loaded', response.response_text.length, 'bytes');

            callbacks.onSuccess({
                url: url,
                data: response.response_text
            }, self.stats, context, null);
        } else {
            console.error('[HLSLoader] HTTP Error:', response ? response.status : 'no response');
            var error = {
                code: response ? response.status : 0,
                text: 'HTTP Error ' + (response ? response.status : 'unknown')
            };
            callbacks.onError(error, context, null, self.stats);
        }
    }).catch(function(e) {
        if (self.stats.aborted) {
            return;
        }
        console.error('[HLSLoader] Load error:', e);
        callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
    });
};

Desktop_HLSLoader.prototype.abort = function() {
    console.log('[HLSLoader] Aborting');
    this.stats.aborted = true;
};

Desktop_HLSLoader.prototype.destroy = function() {
    this.abort();
};

//=============================================================================
// HLS.JS FRAGMENT LOADER (for video segments)
// Routes video segment requests through Tauri backend to bypass CORS
//=============================================================================

// Custom fragment loader class for HLS.js that uses Tauri for binary data
var Desktop_HLSFragmentLoader = function(config) {
    var self = this;
    self.stats = {
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
    self.context = null;
    self.callbacks = null;
    self.retryDelay = 0;
};

Desktop_HLSFragmentLoader.prototype.load = function(context, config, callbacks) {
    var self = this;
    self.context = context;
    self.callbacks = callbacks;
    self.stats.loading.start = performance.now();
    self.retryDelay = config.retryDelay || 0;

    var url = context.url;

    // Use Tauri backend to fetch binary data
    Desktop_invoke('fetch_binary', {
        url: url,
        timeout: config.timeout || 30000
    }).then(function(response) {
        if (self.stats.aborted) {
            return;
        }

        self.stats.loading.first = performance.now();
        self.stats.loading.end = performance.now();

        if (response && response.status === 200 && response.data) {
            // Convert array to Uint8Array
            var uint8Array = new Uint8Array(response.data);
            self.stats.loaded = uint8Array.length;
            self.stats.total = uint8Array.length;

            callbacks.onSuccess({
                url: url,
                data: uint8Array.buffer
            }, self.stats, context, null);
        } else {
            console.error('[HLSFragmentLoader] HTTP Error:', response ? response.status : 'no response');
            var error = {
                code: response ? response.status : 0,
                text: 'HTTP Error ' + (response ? response.status : 'unknown')
            };
            callbacks.onError(error, context, null, self.stats);
        }
    }).catch(function(e) {
        if (self.stats.aborted) {
            return;
        }
        console.error('[HLSFragmentLoader] Load error:', e);
        callbacks.onError({ code: 0, text: e.toString() }, context, null, self.stats);
    });
};

Desktop_HLSFragmentLoader.prototype.abort = function() {
    this.stats.aborted = true;
};

Desktop_HLSFragmentLoader.prototype.destroy = function() {
    this.abort();
};

//=============================================================================
// HLS.JS PLAYER IMPLEMENTATION
// Provides video playback for Twitch streams using HLS.js library
//=============================================================================

var Desktop_HLS = null;           // HLS.js instance
var Desktop_VideoElement = null;  // Reference to video element
var Desktop_CurrentQuality = -1;  // -1 = auto
var Desktop_Qualities = [];       // Available quality levels
var Desktop_WhoCalledPlayer = 0;  // 0=live, 1=vod, 2=clip, 3=multi
var Desktop_ResumePosition = 0;   // Position to resume from (ms)
var Desktop_PlayerNumber = 0;     // Player instance (0=main)

var Desktop_playerState = {
    currentTime: 0,
    savedTime: 0,
    playing: false,
    buffering: false,
    ready: false
};

// Get or create video element
function Desktop_getVideoElement() {
    if (!Desktop_VideoElement) {
        Desktop_VideoElement = document.getElementById('clip_player');
        if (!Desktop_VideoElement) {
            Desktop_VideoElement = document.querySelector('video');
        }
    }
    return Desktop_VideoElement;
}

// Check if HLS.js is supported
function Desktop_HLSSupported() {
    return typeof Hls !== 'undefined' && Hls.isSupported();
}

// Initialize HLS.js player
function Desktop_InitHLS() {
    if (Desktop_HLS) {
        Desktop_DestroyHLS();
    }

    if (!Desktop_HLSSupported()) {
        console.error('[DesktopInterface] HLS.js is not supported in this browser');
        return false;
    }

    Desktop_HLS = new Hls({
        debug: false,
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90,
        maxBufferLength: 30,
        maxMaxBufferLength: 600,
        maxBufferSize: 60 * 1000 * 1000, // 60MB
        maxBufferHole: 0.5,
        startLevel: -1, // Auto
        capLevelToPlayerSize: false,
        // Use custom loaders to bypass CORS via Tauri
        pLoader: Desktop_HLSLoader,      // Playlist loader (text m3u8 files)
        fLoader: Desktop_HLSFragmentLoader, // Fragment loader (binary video segments)
        // Twitch-specific optimizations
        manifestLoadingTimeOut: 10000,
        manifestLoadingMaxRetry: 3,
        levelLoadingTimeOut: 10000,
        levelLoadingMaxRetry: 3,
        fragLoadingTimeOut: 20000,
        fragLoadingMaxRetry: 6
    });

    // Attach event handlers
    Desktop_HLS.on(Hls.Events.MANIFEST_PARSED, Desktop_OnManifestParsed);
    Desktop_HLS.on(Hls.Events.LEVEL_SWITCHED, Desktop_OnLevelSwitched);
    Desktop_HLS.on(Hls.Events.ERROR, Desktop_OnHLSError);
    Desktop_HLS.on(Hls.Events.FRAG_BUFFERED, Desktop_OnFragBuffered);

    console.log('[DesktopInterface] HLS.js initialized');
    return true;
}

// Destroy HLS.js instance
function Desktop_DestroyHLS() {
    if (Desktop_HLS) {
        Desktop_HLS.destroy();
        Desktop_HLS = null;
    }
    Desktop_Qualities = [];
    Desktop_CurrentQuality = -1;
    Desktop_playerState.ready = false;
}

// Handle manifest parsed event - qualities are now available
function Desktop_OnManifestParsed(event, data) {
    console.log('[DesktopInterface] Manifest parsed, levels:', data.levels.length);

    Desktop_Qualities = [];
    for (var i = 0; i < data.levels.length; i++) {
        var level = data.levels[i];
        var qualityName = Desktop_GetQualityName(level);
        Desktop_Qualities.push({
            id: i,
            url: level.url ? level.url[0] : '',
            bitrate: level.bitrate || 0,
            resolution: level.height ? (level.width + 'x' + level.height) : 'unknown',
            band: level.bitrate || 0,
            codec: level.videoCodec || 'avc',
            frame: level.frameRate || 30,
            name: qualityName
        });
    }

    Desktop_playerState.ready = true;

    // Notify app that qualities are available
    if (typeof Play_qualitiesReadyCallback === 'function') {
        Play_qualitiesReadyCallback();
    }

    // Start playback
    var video = Desktop_getVideoElement();
    if (video) {
        video.play().catch(function(e) {
            console.warn('[DesktopInterface] Autoplay blocked:', e);
        });
    }

    // Seek to resume position if needed
    if (Desktop_ResumePosition > 0 && Desktop_WhoCalledPlayer === 1) { // VOD
        setTimeout(function() {
            OSInterface_mseekTo(Desktop_ResumePosition);
        }, 500);
    }
}

// Generate quality name from level info
function Desktop_GetQualityName(level) {
    var name = '';
    if (level.height) {
        name = level.height + 'p';
        if (level.frameRate && level.frameRate >= 50) {
            name += Math.round(level.frameRate);
        }
    } else if (level.bitrate) {
        name = Math.round(level.bitrate / 1000) + 'kbps';
    } else {
        name = 'Source';
    }
    return name;
}

// Handle level switch event
function Desktop_OnLevelSwitched(event, data) {
    Desktop_CurrentQuality = data.level;
    console.log('[DesktopInterface] Quality switched to level', data.level);

    // Notify app of quality change
    if (typeof Play_qualityChanged === 'function') {
        Play_qualityChanged();
    }
}

// Handle HLS.js errors
function Desktop_OnHLSError(event, data) {
    console.error('[DesktopInterface] HLS error:', data.type, data.details);

    if (data.fatal) {
        switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
                console.log('[DesktopInterface] Fatal network error, trying to recover...');
                Desktop_HLS.startLoad();
                break;
            case Hls.ErrorTypes.MEDIA_ERROR:
                console.log('[DesktopInterface] Fatal media error, trying to recover...');
                Desktop_HLS.recoverMediaError();
                break;
            default:
                console.error('[DesktopInterface] Unrecoverable error');
                Desktop_DestroyHLS();
                // Notify app of playback error
                if (typeof Play_PlayerCheck === 'function') {
                    Play_PlayerCheck(Desktop_WhoCalledPlayer, data.details);
                }
                break;
        }
    }
}

// Handle fragment buffered
function Desktop_OnFragBuffered(event, data) {
    Desktop_playerState.buffering = false;
}

// Setup video element event listeners
function Desktop_SetupVideoEvents(video) {
    video.addEventListener('playing', function() {
        Desktop_playerState.playing = true;
        Desktop_playerState.buffering = false;
        if (typeof Play_PlayPauseChange === 'function') {
            Play_PlayPauseChange(true, Desktop_WhoCalledPlayer);
        }
    });

    video.addEventListener('pause', function() {
        Desktop_playerState.playing = false;
        if (typeof Play_PlayPauseChange === 'function') {
            Play_PlayPauseChange(false, Desktop_WhoCalledPlayer);
        }
    });

    video.addEventListener('waiting', function() {
        Desktop_playerState.buffering = true;
    });

    video.addEventListener('ended', function() {
        Desktop_playerState.playing = false;
        console.log('[DesktopInterface] Playback ended');
        if (typeof Play_EndStart === 'function') {
            Play_EndStart(Desktop_WhoCalledPlayer);
        }
    });

    video.addEventListener('error', function(e) {
        console.error('[DesktopInterface] Video element error:', e);
    });

    video.addEventListener('timeupdate', function() {
        Desktop_playerState.currentTime = Math.floor(video.currentTime * 1000);
    });
}

//=============================================================================
// OSINTERFACE PLAYER FUNCTIONS
//=============================================================================

function OSInterface_gettime() {
    var video = Desktop_getVideoElement();
    return video ? Math.floor(video.currentTime * 1000) : Desktop_playerState.currentTime;
}

function OSInterface_gettimepreview() {
    return 0;
}

function OSInterface_getsavedtime() {
    return Desktop_playerState.savedTime;
}

function OSInterface_stopVideo() {
    var video = Desktop_getVideoElement();
    if (video) {
        video.pause();
        video.removeAttribute('src');
        video.load();
    }
    Desktop_DestroyHLS();
    Desktop_playerState.playing = false;
    Desktop_playerState.currentTime = 0;
}

function OSInterface_mseekTo(position) {
    var video = Desktop_getVideoElement();
    if (video && !isNaN(position)) {
        video.currentTime = position / 1000;
    }
}

function OSInterface_PlayPauseChange(PlayVodClip) {
    var video = Desktop_getVideoElement();
    if (video) {
        if (video.paused) {
            video.play().catch(function(e) {
                console.warn('[DesktopInterface] Play failed:', e);
            });
        } else {
            video.pause();
        }
    }
}

function OSInterface_PlayPause(state) {
    var video = Desktop_getVideoElement();
    if (video) {
        if (state) {
            video.play().catch(function(e) {
                console.warn('[DesktopInterface] Play failed:', e);
            });
        } else {
            video.pause();
        }
    }
}

function OSInterface_getPlaybackState() {
    var video = Desktop_getVideoElement();
    return video ? !video.paused : Desktop_playerState.playing;
}

function OSInterface_setPlaybackSpeed(speed) {
    var video = Desktop_getVideoElement();
    if (video) {
        video.playbackRate = speed;
    }
}

function OSInterface_SetQuality(position) {
    if (!Desktop_HLS) {
        console.warn('[DesktopInterface] SetQuality called but HLS not initialized');
        return;
    }

    if (position === -1) {
        // Auto quality
        Desktop_HLS.currentLevel = -1;
        Desktop_CurrentQuality = -1;
        console.log('[DesktopInterface] Quality set to auto');
    } else if (position >= 0 && position < Desktop_Qualities.length) {
        Desktop_HLS.currentLevel = position;
        Desktop_CurrentQuality = position;
        console.log('[DesktopInterface] Quality set to level', position);
    }
}

function OSInterface_getQualities() {
    if (Desktop_Qualities.length === 0) {
        return '[]';
    }

    // Return qualities in the format the app expects
    var result = [];
    for (var i = 0; i < Desktop_Qualities.length; i++) {
        var q = Desktop_Qualities[i];
        result.push({
            id: q.id,
            bitrate: q.bitrate,
            resolution: q.resolution,
            band: q.band,
            codec: q.codec,
            frame: q.frame
        });
    }
    return JSON.stringify(result);
}

function OSInterface_getDuration(callback) {
    var video = Desktop_getVideoElement();
    if (video && callback) {
        var duration = isNaN(video.duration) ? 0 : Math.floor(video.duration * 1000);
        try {
            eval(callback + '(' + duration + ')'); // jshint ignore:line
        } catch (e) {
            console.error('[DesktopInterface] getDuration callback error:', e);
        }
    }
}

//=============================================================================
// VOLUME FUNCTIONS (Using HTML5 video element)
//=============================================================================

function OSInterface_SetVolumes() {
    var video = Desktop_getVideoElement();
    if (video && typeof Play_volumes !== 'undefined') {
        video.volume = Play_volumes[0] / 100;
    }
}

function OSInterface_SetAudioEnabled() {
    var video = Desktop_getVideoElement();
    if (video && typeof Play_audio_enable !== 'undefined') {
        video.muted = !Play_audio_enable[0];
    }
}

function OSInterface_ApplyAudio() {
    // No-op for desktop - volume changes are applied immediately
}

//=============================================================================
// STREAM PLAYBACK - Start/Stop/Restart functions
//=============================================================================

// Main entry point for starting stream playback
// uri: Master playlist URL (m3u8)
// mainPlaylistString: Full HLS manifest content
// who_called: 0=Live, 1=VOD, 2=Clip, 3=Multi-stream
// ResumePosition: Position in milliseconds (0 for live)
// player: Player instance (0=main, 1-3=multi-stream)
function OSInterface_StartAuto(uri, mainPlaylistString, who_called, ResumePosition, player) {
    console.log('[DesktopInterface] StartAuto called', {
        uri: uri ? uri.substring(0, 100) + '...' : 'null',
        who_called: who_called,
        ResumePosition: ResumePosition,
        player: player
    });

    // Store state
    Desktop_WhoCalledPlayer = who_called || 0;
    Desktop_ResumePosition = ResumePosition || 0;
    Desktop_PlayerNumber = player || 0;

    // Get video element
    var video = Desktop_getVideoElement();
    if (!video) {
        console.error('[DesktopInterface] No video element found');
        return;
    }

    // Check if HLS.js is supported
    if (!Desktop_HLSSupported()) {
        // Fallback to native HLS (Safari)
        if (video.canPlayType('application/vnd.apple.mpegurl')) {
            console.log('[DesktopInterface] Using native HLS support');
            video.src = uri;
            video.addEventListener('loadedmetadata', function() {
                if (ResumePosition > 0 && who_called === 1) {
                    video.currentTime = ResumePosition / 1000;
                }
                video.play();
            });
            Desktop_SetupVideoEvents(video);
            return;
        }
        console.error('[DesktopInterface] HLS.js not supported and no native support');
        return;
    }

    // Initialize HLS.js
    if (!Desktop_InitHLS()) {
        return;
    }

    // Setup video events
    Desktop_SetupVideoEvents(video);

    // Attach HLS to video element
    Desktop_HLS.attachMedia(video);

    // Load the stream
    Desktop_HLS.on(Hls.Events.MEDIA_ATTACHED, function() {
        console.log('[DesktopInterface] HLS attached to video element');

        // If we have the manifest content, use a blob URL to avoid CORS for master manifest
        if (mainPlaylistString && mainPlaylistString.length > 0) {
            console.log('[DesktopInterface] Using pre-fetched manifest, length:', mainPlaylistString.length);
            var blob = new Blob([mainPlaylistString], { type: 'application/vnd.apple.mpegurl' });
            var blobUrl = URL.createObjectURL(blob);
            Desktop_HLS.loadSource(blobUrl);
            // Clean up blob URL after a delay
            setTimeout(function() {
                URL.revokeObjectURL(blobUrl);
            }, 30000);
        } else {
            // Fallback to direct URL (will use custom loader)
            Desktop_HLS.loadSource(uri);
        }
    });
}

// Restart current playback
function OSInterface_RestartPlayer(who_called, ResumePosition, player) {
    console.log('[DesktopInterface] RestartPlayer called');

    if (Desktop_HLS && Desktop_HLS.url) {
        var currentUrl = Desktop_HLS.url;
        Desktop_WhoCalledPlayer = who_called || Desktop_WhoCalledPlayer;
        Desktop_ResumePosition = ResumePosition || 0;

        // Reload the same stream
        Desktop_HLS.loadSource(currentUrl);
    }
}

// Reuse feed player (for picture-in-picture previews)
function OSInterface_ReuseFeedPlayer(uri, mainPlaylistString, who_called, ResumePosition, player) {
    console.log('[DesktopInterface] ReuseFeedPlayer - redirecting to StartAuto');
    OSInterface_StartAuto(uri, mainPlaylistString, who_called, ResumePosition, player);
}

//=============================================================================
// STUB FUNCTIONS - No-op for desktop
// These Android-specific functions are kept as stubs to prevent errors
//=============================================================================

// Notifications (will be replaced with in-app notifications in Phase 4)
function OSInterface_StopNotificationService() {}
function OSInterface_SetNotificationPosition(position) {}
function OSInterface_SetNotificationRepeat(times) {}
function OSInterface_SetNotificationSinceTime(time) {}
function OSInterface_RunNotificationService() {}
function OSInterface_upNotificationState(Notify) {}
function OSInterface_hasNotificationPermission() { return true; }
function OSInterface_SetNotificationLive(Notify) {}
function OSInterface_SetNotificationTitle(Notify) {}
function OSInterface_SetNotificationGame(Notify) {}

// Settings stubs
function OSInterface_Settings_SetPingWarning(warning) {}
function OSInterface_SetCheckSource(mCheckSource) {}

// Player advanced (multi-stream deferred)
function OSInterface_mupdatesizePP(isFullScreen) {}
function OSInterface_mupdatesize(isFullScreen) {}
function OSInterface_SetFullScreenPosition(mFullScreenPosition) {}
function OSInterface_SetFullScreenSize(mFullScreenSize) {}
function OSInterface_mSetPlayerPosition(PicturePicturePos) {}
function OSInterface_mSetPlayerSize(mPicturePictureSize) {}
function OSInterface_msetPlayer(surface_view, FullScreen) {}
function OSInterface_mSetlatency(LowLatency) {}
function OSInterface_mSwitchPlayerSize(PicturePictureSize) {}
function OSInterface_mSwitchPlayer() {}
function OSInterface_mSwitchPlayerPosition(mPicturePicturePosition) {}
function OSInterface_ReuseFeedPlayerPrepare(trackSelectorPos) {}
function OSInterface_FixViewPosition(position, Type) {}

// Multi-stream (deferred)
function OSInterface_DisableMultiStream() {}
function OSInterface_StartMultiStream(position, uri, mainPlaylistString, Restart) {}
function OSInterface_EnableMultiStream(MainBig, offset) {}

// Feed/Screen players (deferred)
function OSInterface_StartFeedPlayer(uri, mainPlaylistString, position, resumePosition, isVod) {}
function OSInterface_StartSidePanelPlayer(uri, mainPlaylistString) {}
function OSInterface_SetPlayerViewFeedBottom(bottom, web_height) {}
function OSInterface_SetPlayerViewSidePanel(bottom, right, left, web_height) {}
function OSInterface_StartScreensPlayer(uri, mainPlaylistString, ResumePosition, bottom, right, left, web_height, who_called) {}
function OSInterface_ScreenPlayerRestore(bottom, right, left, web_height, who_called) {}
function OSInterface_ClearFeedPlayer() {}
function OSInterface_ClearSidePanelPlayer() {}
function OSInterface_SidePanelPlayerRestore() {}
function OSInterface_SetFeedPosition(position) {}
function OSInterface_mClearSmallPlayer() {}

// UI stubs
function OSInterface_mhideSystemUI() {}
function OSInterface_mshowLoading(show) {
    // Use CSS loading indicator
    var loadingEl = document.getElementById('dialog_loading');
    if (loadingEl) {
        loadingEl.style.display = show ? 'block' : 'none';
    }
}
function OSInterface_mshowLoadingBottom(show) {}
function OSInterface_showToast(toast) {
    console.log('[Toast]', toast);
}
function OSInterface_mCheckRefreshToast(type) {}
function OSInterface_mCheckRefresh() {}

// Keyboard/Input stubs
function OSInterface_KeyboardCheckAndHIde() {}
function OSInterface_hideKeyboardFrom() {}
function OSInterface_keyEvent(key, keyaction) {}
function OSInterface_AvoidClicks(Avoid) {}
function OSInterface_initbodyClickSet() {}
function OSInterface_SetKeysOpacity(Opacity) {}
function OSInterface_SetKeysPosition(Position) {}

// Audio advanced stubs
function OSInterface_SetPreviewSize(mPreviewSize) {}
function OSInterface_SetPreviewAudio(volume) {}
function OSInterface_SetPreviewOthersAudio(volume) {}

// Blocked content
function OSInterface_UpdateBlockedChannels() {}
function OSInterface_UpdateBlockedGames() {}

// Bandwidth/Quality
function OSInterface_SetSmallPlayerBitrate(Bitrate, Resolution) {}
function OSInterface_SetMainPlayerBitrate(Bitrate, Resolution) {}
function OSInterface_getcodecCapabilities(CodecType) { return '{}'; }
function OSInterface_setBlackListMediaCodec(CodecList) {}
function OSInterface_setBlackListQualities(qualitiesList) {}
function OSInterface_setSpeedAdjustment(speedAdjustment) {}

// Tokens/Auth
function OSInterface_setAppToken() {}
function OSInterface_UpdateUserId(user) {}
function OSInterface_setAppIds(client_id, client_secret, redirect_uri) {}

// External
function OSInterface_OpenExternal(url) {
    window.open(url, '_blank');
}

// Misc
function OSInterface_isAccessibilitySettingsOn() { return false; }
function OSInterface_LongLog(log) {
    console.log('[LongLog]', log);
}
function OSInterface_getVideoStatus(showLatency, Who_Called) {
    // Provide video status to the app
    if (typeof Play_ShowVideoStatus === 'function') {
        var video = Desktop_getVideoElement();
        var buffered = 0;
        if (video && video.buffered && video.buffered.length > 0) {
            buffered = video.buffered.end(video.buffered.length - 1) - video.currentTime;
        }
        var status = {
            droppedFrames: 0,
            bufferLength: Math.floor(buffered * 1000),
            bandwidth: Desktop_HLS ? Desktop_HLS.bandwidthEstimate : 0
        };
        Play_ShowVideoStatus(status, Who_Called);
    }
}

function OSInterface_getVideoQuality(who_called) {
    // Report current quality for auto mode
    if (Desktop_HLS && Desktop_CurrentQuality >= 0 && Desktop_Qualities.length > 0) {
        var quality = Desktop_Qualities[Desktop_CurrentQuality];
        if (quality && typeof Play_updateQualityDisplay === 'function') {
            Play_updateQualityDisplay(quality.name || quality.resolution, who_called);
        }
    }
}
function OSInterface_GetLastIntentObj() { return null; }
function OSInterface_upDateLang(lang) {}
function OSInterface_getLatency(chat_number) {}
function OSInterface_mKeepScreenOn(keepOn) {}
function OSInterface_getInstallFromPLay() { return true; } // Always true to prevent APK update attempts
function OSInterface_UpdateAPK(apkURL, failAll, failDownload) {}
function OSInterface_CleanAndLoadUrl(url) {
    window.location.href = url;
}
function OSInterface_SetLanguage(lang) {}
function OSInterface_updateScreenDuration(callback, key, obj_id) {}

// Low latency array for compatibility
var low_latency_array = [0, 2, 1];

//=============================================================================
// MOUSE SUPPORT - Click handlers for desktop navigation
//=============================================================================

var Desktop_MouseEnabled = true;
var Desktop_MouseClickDelay = 150; // Prevent double-clicks
var Desktop_LastClickTime = 0;

// Initialize mouse support when DOM is ready
function Desktop_InitMouse() {
    if (!Desktop_MouseEnabled) return;

    // Add CSS for pointer cursor on interactive elements
    Desktop_AddMouseCSS();

    // Add click event delegation
    document.addEventListener('click', Desktop_HandleClick, true);

    console.log('[DesktopInterface] Mouse support initialized');
}

// Add CSS for mouse cursor on interactive elements
function Desktop_AddMouseCSS() {
    var style = document.getElementById('desktop_mouse_css');
    if (!style) {
        style = document.createElement('style');
        style.id = 'desktop_mouse_css';
        document.head.appendChild(style);
    }

    style.textContent = [
        // Thumbnails and cards
        '.stream_thumbnail, .stream_thumbnail_live, .stream_thumbnail_vod, .stream_thumbnail_clip,',
        '.stream_thumbnail_game, .stream_thumbnail_channel, .stream_thumbnail_user,',
        '.stream_thumbnail_player_feed, .feed_thumbnail, .side_panel_holder,',
        // Sidebar menu items
        '.side_panel_new_icons_div, .side_panel_movel_user,',
        '[id^="side_panel_movel_new_"], [id^="side_panel_new_"],',
        // Sidebar feed items
        '.side_panel_feed, [id^="usf_thumbdiv"],',
        // Settings items
        '.settings_div, .settings_value,',
        // Buttons and switches
        '.stream_switch, .dialog_button,',
        // General clickable elements
        '[class*="thumbnail"], [class*="_cell_"], [class*="thumb"]',
        '{ cursor: pointer !important; }',
        '',
        // Hover effects
        '.stream_thumbnail:hover, .feed_thumbnail:hover, [class*="thumbnail"]:hover,',
        '[id^="side_panel_movel_new_"]:hover, .side_panel_feed:hover',
        '{ opacity: 0.85; }',
        '',
        // Sidebar menu hover
        '.side_panel_new_icons_div:hover { background-color: rgba(255,255,255,0.1); }'
    ].join('\n');
}

// Handle click events via delegation
function Desktop_HandleClick(event) {
    // Prevent rapid double-clicks
    var now = Date.now();
    if (now - Desktop_LastClickTime < Desktop_MouseClickDelay) {
        return;
    }
    Desktop_LastClickTime = now;

    var target = event.target;

    // Find the closest clickable element
    var clickable = Desktop_FindClickableElement(target);

    if (clickable) {
        event.preventDefault();
        event.stopPropagation();
        Desktop_HandleElementClick(clickable);
    }
}

// Find the closest clickable parent element
function Desktop_FindClickableElement(element) {
    var maxDepth = 15;
    var depth = 0;

    while (element && depth < maxDepth) {
        if (element === document.body || element === document.documentElement) {
            return null;
        }

        var id = element.id || '';
        var className = element.className || '';

        // Check for sidebar menu items (highest priority)
        if (Desktop_IsSidebarMenuItem(id, className)) {
            return { element: element, type: 'sidebar_menu', id: id };
        }

        // Check for sidebar feed items
        if (Desktop_IsSidebarFeedItem(id, className)) {
            return { element: element, type: 'sidebar_feed', id: id };
        }

        // Check for thumbnail elements (main navigation)
        if (Desktop_IsThumbnailElement(id, className)) {
            return { element: element, type: 'thumbnail', id: id };
        }

        // Check for settings elements
        if (Desktop_IsSettingsElement(id, className)) {
            return { element: element, type: 'settings', id: id };
        }

        // Check for dialog buttons
        if (Desktop_IsButtonElement(id, className)) {
            return { element: element, type: 'button', id: id };
        }

        // Check for switch elements (tabs)
        if (Desktop_IsSwitchElement(id, className)) {
            return { element: element, type: 'switch', id: id };
        }

        element = element.parentElement;
        depth++;
    }

    return null;
}

// Check if element is a sidebar menu item
function Desktop_IsSidebarMenuItem(id, className) {
    // Match side_panel_movel_new_X or side_panel_new_X
    if (id && /^side_panel_(movel_)?new_\d+$/.test(id)) {
        return true;
    }
    // Match container divs
    if (typeof className === 'string' &&
        (className.indexOf('side_panel_new_icons_div') !== -1 ||
         className.indexOf('side_panel_movel_user') !== -1)) {
        return true;
    }
    return false;
}

// Check if element is a sidebar feed item
function Desktop_IsSidebarFeedItem(id, className) {
    // Match usf_thumbdiv_X pattern
    if (id && /^usf_thumbdiv_\d+$/.test(id)) {
        return true;
    }
    // Match feed class
    if (typeof className === 'string' && className.indexOf('side_panel_feed') !== -1) {
        return true;
    }
    return false;
}

// Check if element is a thumbnail (grid item)
function Desktop_IsThumbnailElement(id, className) {
    // Match patterns like: thumbdiv0_1, s_live_thumbdiv0_1, etc.
    if (id && /thumbdiv\d+_\d+/.test(id)) {
        return true;
    }
    // Match thumbnail class patterns
    if (typeof className === 'string' &&
        (className.indexOf('stream_thumbnail') !== -1 ||
         className.indexOf('feed_thumbnail') !== -1)) {
        return true;
    }
    return false;
}

// Check if element is a settings item
function Desktop_IsSettingsElement(id, className) {
    if (typeof className === 'string' &&
        (className.indexOf('settings_div') !== -1 ||
         className.indexOf('settings_value') !== -1)) {
        return true;
    }
    return false;
}

// Check if element is a button
function Desktop_IsButtonElement(id, className) {
    if (typeof className === 'string' &&
        className.indexOf('dialog_button') !== -1) {
        return true;
    }
    return false;
}

// Check if element is a switch/tab
function Desktop_IsSwitchElement(id, className) {
    if (typeof className === 'string' &&
        className.indexOf('stream_switch') !== -1) {
        return true;
    }
    // Match switch patterns like: thumbdivy_0, thumbdivy_1
    if (id && /thumbdivy_\d+/.test(id)) {
        return true;
    }
    return false;
}

// Handle the click on an identified element
function Desktop_HandleElementClick(clickInfo) {
    var element = clickInfo.element;
    var type = clickInfo.type;
    var id = clickInfo.id;

    switch (type) {
        case 'sidebar_menu':
            Desktop_HandleSidebarMenuClick(id);
            break;
        case 'sidebar_feed':
            Desktop_HandleSidebarFeedClick(id);
            break;
        case 'thumbnail':
            Desktop_HandleThumbnailClick(id);
            break;
        case 'settings':
        case 'button':
        case 'switch':
            Desktop_SimulateEnter();
            break;
        default:
            Desktop_SimulateEnter();
    }
}

// Handle sidebar menu item click
function Desktop_HandleSidebarMenuClick(id) {
    // Extract position from ID (e.g., side_panel_movel_new_5 -> 5)
    var match = id.match(/(\d+)$/);
    if (!match) return;

    var position = parseInt(match[1], 10);

    // Ensure sidebar is open and in main menu mode
    if (typeof Sidepannel_IsMain !== 'undefined' && typeof Sidepannel_Sidepannel_Pos !== 'undefined') {
        // Open sidebar if not already open
        if (typeof Sidepannel_Start === 'function' && typeof ScreenObj !== 'undefined' && typeof Main_values !== 'undefined') {
            var key = Main_values.Main_Go;
            if (ScreenObj[key] && ScreenObj[key].key_fun) {
                // Check if sidebar is visible
                var holder = document.getElementById('side_panel_new_holder');
                if (!holder || holder.classList.contains('hide')) {
                    // Open sidebar first
                    if (typeof Screens_OpenSidePanel === 'function') {
                        Screens_OpenSidePanel(false, key);
                    }
                    // Wait for sidebar to open, then navigate
                    setTimeout(function() {
                        Desktop_NavigateToSidebarPosition(position);
                    }, 100);
                    return;
                }
            }
        }

        // Navigate to position and trigger enter
        Desktop_NavigateToSidebarPosition(position);
    }
}

// Navigate to sidebar menu position and trigger action
function Desktop_NavigateToSidebarPosition(position) {
    if (typeof Sidepannel_RemoveFocusMain === 'function') {
        Sidepannel_RemoveFocusMain();
    }

    // Set to main menu mode
    if (typeof Sidepannel_IsMain !== 'undefined') {
        Sidepannel_IsMain = true;
    }

    // Update position
    if (typeof Sidepannel_Sidepannel_Pos !== 'undefined') {
        Sidepannel_Sidepannel_Pos = position;
    }

    if (typeof Sidepannel_AddFocusMain === 'function') {
        Sidepannel_AddFocusMain();
    }

    // Trigger the action
    setTimeout(function() {
        if (typeof Sidepannel_KeyEnter === 'function') {
            Sidepannel_KeyEnter();
        } else {
            Desktop_SimulateEnter();
        }
    }, 50);
}

// Handle sidebar feed item click
function Desktop_HandleSidebarFeedClick(id) {
    // Extract position from ID (e.g., usf_thumbdiv_5 -> 5)
    var match = id.match(/(\d+)$/);
    if (!match) return;

    var position = parseInt(match[1], 10);

    // Ensure we're in feed mode
    if (typeof Sidepannel_IsMain !== 'undefined') {
        Sidepannel_IsMain = false;
    }

    // Remove old focus
    if (typeof Sidepannel_RemoveFocusFeed === 'function') {
        Sidepannel_RemoveFocusFeed(false);
    }

    // Update position
    if (typeof Sidepannel_PosFeed !== 'undefined') {
        Sidepannel_PosFeed = position;
    }

    // Add new focus
    if (typeof Sidepannel_AddFocusLiveFeed === 'function') {
        Sidepannel_AddFocusLiveFeed(false);
    }

    // Trigger the action
    setTimeout(function() {
        if (typeof Sidepannel_userLiveKeyEnter === 'function') {
            Sidepannel_userLiveKeyEnter();
        } else {
            Desktop_SimulateEnter();
        }
    }, 50);
}

// Handle main grid thumbnail click
function Desktop_HandleThumbnailClick(id) {
    // Try to parse position from ID (format: prefix_Y_X or prefixY_X)
    var posMatch = id.match(/(\d+)_(\d+)$/);

    if (posMatch) {
        var posY = parseInt(posMatch[1], 10);
        var posX = parseInt(posMatch[2], 10);
        Desktop_NavigateToPosition(posY, posX);
    } else {
        Desktop_SimulateEnter();
    }
}

// Navigate to a specific grid position and trigger enter
function Desktop_NavigateToPosition(posY, posX) {
    // Get current screen object
    if (typeof ScreenObj === 'undefined' || typeof Main_values === 'undefined') {
        return;
    }

    var key = Main_values.Main_Go;
    var screen = ScreenObj[key];

    if (!screen || !screen.FirstRunEnd) {
        return;
    }

    // Move focus to the clicked position
    if (typeof Screens_RemoveFocus === 'function') {
        Screens_RemoveFocus(key);
    }

    screen.posY = posY;
    screen.posX = posX;

    if (typeof Screens_addFocus === 'function') {
        Screens_addFocus(false, key);
    }

    // Trigger the enter/play action after a short delay
    setTimeout(function() {
        Desktop_SimulateEnter();
    }, 50);
}

// Simulate pressing the Enter key
function Desktop_SimulateEnter() {
    var event = new KeyboardEvent('keydown', {
        bubbles: true,
        cancelable: true,
        keyCode: 13, // KEY_ENTER
        which: 13
    });
    document.body.dispatchEvent(event);

    // Also dispatch keyup
    setTimeout(function() {
        var upEvent = new KeyboardEvent('keyup', {
            bubbles: true,
            cancelable: true,
            keyCode: 13,
            which: 13
        });
        document.body.dispatchEvent(upEvent);
    }, 100);
}

// Initialize mouse support when document is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', Desktop_InitMouse);
} else {
    // DOM already loaded
    setTimeout(Desktop_InitMouse, 100);
}

console.log('[DesktopInterface] Initialized - Version:', OSInterface_getversion());
