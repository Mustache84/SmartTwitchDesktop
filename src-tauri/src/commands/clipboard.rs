use tauri::command;

/// Write text to the system clipboard
#[command]
pub async fn mwritetoclipboard(text: String) -> Result<(), String> {
    use std::process::Command;

    #[cfg(target_os = "windows")]
    {
        // Use PowerShell to write to clipboard on Windows
        Command::new("powershell")
            .args(["-Command", &format!("Set-Clipboard -Value '{}'", text.replace("'", "''"))])
            .output()
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    #[cfg(target_os = "macos")]
    {
        use std::io::Write;
        let mut child = Command::new("pbcopy")
            .stdin(std::process::Stdio::piped())
            .spawn()
            .map_err(|e| e.to_string())?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(text.as_bytes()).map_err(|e| e.to_string())?;
        }
        child.wait().map_err(|e| e.to_string())?;
        Ok(())
    }

    #[cfg(target_os = "linux")]
    {
        use std::io::Write;
        // Try xclip first, fall back to xsel
        let result = Command::new("xclip")
            .args(["-selection", "clipboard"])
            .stdin(std::process::Stdio::piped())
            .spawn();

        match result {
            Ok(mut child) => {
                if let Some(mut stdin) = child.stdin.take() {
                    stdin.write_all(text.as_bytes()).map_err(|e| e.to_string())?;
                }
                child.wait().map_err(|e| e.to_string())?;
                Ok(())
            }
            Err(_) => {
                let mut child = Command::new("xsel")
                    .args(["--clipboard", "--input"])
                    .stdin(std::process::Stdio::piped())
                    .spawn()
                    .map_err(|e| e.to_string())?;

                if let Some(mut stdin) = child.stdin.take() {
                    stdin.write_all(text.as_bytes()).map_err(|e| e.to_string())?;
                }
                child.wait().map_err(|e| e.to_string())?;
                Ok(())
            }
        }
    }
}

/// Read text from the system clipboard
#[command]
pub async fn mreadclipboard() -> Result<String, String> {
    use std::process::Command;

    #[cfg(target_os = "windows")]
    {
        let output = Command::new("powershell")
            .args(["-Command", "Get-Clipboard"])
            .output()
            .map_err(|e| e.to_string())?;

        String::from_utf8(output.stdout)
            .map(|s| s.trim().to_string())
            .map_err(|e| e.to_string())
    }

    #[cfg(target_os = "macos")]
    {
        let output = Command::new("pbpaste")
            .output()
            .map_err(|e| e.to_string())?;

        String::from_utf8(output.stdout)
            .map_err(|e| e.to_string())
    }

    #[cfg(target_os = "linux")]
    {
        // Try xclip first, fall back to xsel
        let result = Command::new("xclip")
            .args(["-selection", "clipboard", "-o"])
            .output();

        match result {
            Ok(output) => String::from_utf8(output.stdout).map_err(|e| e.to_string()),
            Err(_) => {
                let output = Command::new("xsel")
                    .args(["--clipboard", "--output"])
                    .output()
                    .map_err(|e| e.to_string())?;
                String::from_utf8(output.stdout).map_err(|e| e.to_string())
            }
        }
    }
}
