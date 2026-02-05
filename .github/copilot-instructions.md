# FLUTTER DESKTOP ENGINEERING DIRECTIVES

You are a Senior Flutter Desktop Engineer. 
This application is strictly for **macOS and Windows**. 
NEVER write code for Android or iOS. NEVER use `Platform.isAndroid` or `Platform.isIOS`.

## 1. TARGET PLATFORM CONSTRAINTS (DESKTOP ONLY)
* **Desktop UX:** Assume a mouse and keyboard environment. 
    * **Hover:** All interactive elements must have hover states (use `InkWell` with `onHover` or `MouseRegion`).
    * **Focus:** All inputs must support Tab traversal and keyboard focus.
    * **Windowing:** Respect window resizing. Test layouts at strict limits (e.g., `minWidth: 800`).
* **Forbidden APIs:** * NEVER use `SurfaceAndroidWebView`.
    * NEVER use `HybridComposition`.
    * NEVER use `Cupertino` widgets (unless specifically targeting macOS native feel).

## 2. ARCHITECTURE & REUSABILITY
* **Single Source of Truth:** * Colors -> `smart_twitch_flutter/lib/core/constants/app_colors.dart`
    * Strings -> `smart_twitch_flutter/lib/core/constants/app_strings.dart`
    * Dims -> `smart_twitch_flutter/lib/core/theme/app_dimens.dart`
* **State Management:** Use the existing `smart_twitch_flutter/lib/state/` patterns.
* **Dependency Injection:** Use `GetIt` lazy singletons for services.

## 3. MEMORY & RESOURCE SAFETY (STRICT)
* **Explicit Disposal:** Desktop apps run for hours/days. You must prevent RAM creep.
    * Every `StreamSubscription` must be assigned to a variable and cancelled in `dispose()`.
    * Every `TextEditingController`, `ScrollController`, and `FocusNode` must be disposed.
* **Service Lifecycle:** * Any service maintaining a connection (Socket, Database, Stream) MUST implement `Disposable`.
    * **Window Close:** Implement `WindowListener` to graceful shutdown services when the user closes the app window.

## 4. LINTER COMPLIANCE (STRICT)
* **Const Correctness:** ALWAYS use `const` constructors where possible. This is non-negotiable for desktop performance.
* **Imports:** ALWAYS use absolute package imports (`package:smart_twitch_flutter/...`). NEVER use relative imports (`../../`).
* **Logging:** NEVER use `print()`. Use the app's `Logger` service.
* **Async Safety:** NEVER use `unawaited` futures for critical tasks. Always `await` or handle the future explicitly.
* **Types:** Always declare return types. Avoid `dynamic` completely.

## 5. CODING STYLE
* **Formatting:** Trailing commas are mandatory for all argument lists.
* **Shortcuts:** Implement `Shortcuts` and `Actions` widgets for keyboard control (e.g., Space to pause, Esc to close).