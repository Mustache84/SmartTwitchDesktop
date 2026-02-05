---
applyTo: 
  - "smart_twitch_flutter/lib/screens/**"
  - "smart_twitch_flutter/lib/widgets/**"
---

# DESKTOP WEBVIEW RULES
You are implementing WebViews for a Desktop Application (Windows/macOS).

1. **Platform Implementation:** - Ensure the WebView controller is compatible with Desktop targets (using `webview_windows` or the specific desktop implementation of `webview_flutter`).
   - NEVER try to initialize `AndroidWebView` or `IOSWebView`.

2. **User Agent:** - ALWAYS set a Desktop UserAgent. Do not let the WebView default to a mobile UserAgent, or Twitch will serve the mobile site.
   - *Example:* "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36..."

3. **Performance:**
   - Desktop WebViews are heavy. Only instantiate them when visible. 
   - Dispose of the controller immediately when the widget is removed from the tree.

4. **Inputs:**
   - Ensure keyboard events (Spacebar, Arrows) are passed correctly to the WebView if it has focus.