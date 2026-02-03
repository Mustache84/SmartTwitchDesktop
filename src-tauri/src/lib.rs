use tauri::{WebviewUrl, WebviewWindowBuilder};

mod commands;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Get version and debug info at startup
    let version = env!("CARGO_PKG_VERSION");
    let is_debug = cfg!(debug_assertions);
    let device = std::env::consts::OS;

    // Create initialization script that sets up desktop detection variables
    // These are read by DesktopInterface.js for platform detection
    let init_script = format!(
        r#"
        // Desktop platform detection variables
        // Used by DesktopInterface.js to detect Tauri environment
        window.__TAURI_BRIDGE_VERSION__ = "Desktop-{}";
        window.__TAURI_BRIDGE_DEBUG__ = {};
        window.__TAURI_BRIDGE_DEVICE__ = "{}";
        console.log('[Tauri] Desktop environment initialized:', window.__TAURI_BRIDGE_VERSION__);
        "#,
        version,
        is_debug,
        device
    );

    tauri::Builder::default()
        .setup(move |app| {
            // Create the main window with initialization script
            let _window = WebviewWindowBuilder::new(
                app,
                "main",
                WebviewUrl::App("index.html".into())
            )
            .title("SmartTwitchTV Desktop")
            .inner_size(1280.0, 720.0)
            .resizable(true)
            .initialization_script(&init_script)
            .build()?;

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // HTTP commands (for CORS bypass)
            commands::http::m_method_url_headers,
            commands::http::base_xml_http_get,
            commands::http::xml_http_get_full,
            commands::http::fetch_binary,
            // Window commands
            commands::window::mclose,
            commands::window::show_toast,
            // Clipboard commands
            commands::clipboard::mwritetoclipboard,
            commands::clipboard::mreadclipboard,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
