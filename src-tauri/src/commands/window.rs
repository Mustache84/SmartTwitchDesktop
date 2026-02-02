use tauri::{command, AppHandle, Manager};

/// Close or minimize the application window
/// If close is true, exit the app. If false, minimize.
#[command]
pub async fn mclose(app: AppHandle, close: bool) -> Result<(), String> {
    if close {
        app.exit(0);
    } else {
        if let Some(window) = app.get_webview_window("main") {
            window.minimize().map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

/// Show a toast notification (logs to console for now)
#[command]
pub fn show_toast(toast: String) {
    println!("[Toast] {}", toast);
}
