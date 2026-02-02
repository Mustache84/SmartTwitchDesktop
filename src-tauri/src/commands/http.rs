use serde::{Deserialize, Serialize};
use tauri::{command, WebviewWindow};
use std::time::Duration;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct HttpResponse {
    pub status: u16,
    pub response_text: String,
}

/// Perform an HTTP request with custom headers
async fn perform_http_request(
    url: &str,
    timeout_ms: u64,
    post_message: Option<String>,
    method: Option<String>,
    json_headers_array: Option<String>,
) -> Result<HttpResponse, String> {
    let client = reqwest::Client::new();
    let method_str = method.unwrap_or_else(|| "GET".to_string());

    let mut request = match method_str.to_uppercase().as_str() {
        "POST" => client.post(url),
        "PUT" => client.put(url),
        "DELETE" => client.delete(url),
        _ => client.get(url),
    };

    request = request.timeout(Duration::from_millis(timeout_ms.max(1000)));

    // Parse and apply headers from JSON array format: [["header", "value"], ...]
    if let Some(headers_json) = json_headers_array {
        if !headers_json.is_empty() {
            if let Ok(headers) = serde_json::from_str::<Vec<Vec<String>>>(&headers_json) {
                for header in headers {
                    if header.len() >= 2 {
                        if let Ok(name) = reqwest::header::HeaderName::try_from(&header[0]) {
                            if let Ok(value) = reqwest::header::HeaderValue::try_from(&header[1]) {
                                request = request.header(name, value);
                            }
                        }
                    }
                }
            }
        }
    }

    // Add body if present
    if let Some(body) = post_message {
        if !body.is_empty() {
            request = request.body(body);
        }
    }

    match request.send().await {
        Ok(response) => {
            let status = response.status().as_u16();
            let text = response.text().await.unwrap_or_default();

            Ok(HttpResponse {
                status,
                response_text: text,
            })
        }
        Err(e) => {
            Ok(HttpResponse {
                status: 0,
                response_text: e.to_string(),
            })
        }
    }
}

/// Escape a string for safe use in JavaScript
fn escape_js_string(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('\'', "\\'")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

/// Synchronous HTTP request - used by mMethodUrlHeaders
/// Returns the response directly as a JSON string
#[command]
pub async fn m_method_url_headers(
    url_string: String,
    timeout: u64,
    post_message: Option<String>,
    method: Option<String>,
    _check_result: i64,
    json_headers_array: Option<String>,
) -> Result<String, String> {
    let result = perform_http_request(
        &url_string,
        timeout,
        post_message,
        method,
        json_headers_array,
    )
    .await?;

    // Return the response text directly (matching Android behavior)
    Ok(result.response_text)
}

/// Async HTTP with callback - used by BaseXmlHttpGet
/// Executes callback function in the webview with the result
#[command]
pub async fn base_xml_http_get(
    window: WebviewWindow,
    url_string: String,
    timeout: u64,
    post_message: Option<String>,
    method: Option<String>,
    json_headers_array: Option<String>,
    callback: String,
    check_result: i64,
    key: Option<i64>,
    call_back_success: String,
    call_back_error: String,
) -> Result<(), String> {
    let result = perform_http_request(
        &url_string,
        timeout,
        post_message,
        method,
        json_headers_array,
    )
    .await;

    let key_str = key.map(|k| k.to_string()).unwrap_or_else(|| "0".to_string());

    let js = match result {
        Ok(response) => {
            let escaped_response = escape_js_string(&response.response_text);
            format!(
                "try {{ {}('{}', {}, '{}', '{}', {}); }} catch(e) {{ console.error('Callback error:', e); }}",
                callback,
                escaped_response,
                key_str,
                call_back_success,
                call_back_error,
                check_result
            )
        }
        Err(_) => {
            format!(
                "try {{ {}(null, {}, '{}', '{}', {}); }} catch(e) {{ console.error('Callback error:', e); }}",
                callback,
                key_str,
                call_back_success,
                call_back_error,
                check_result
            )
        }
    };

    window.eval(&js).map_err(|e| e.to_string())
}

/// Full async HTTP with extended parameters - used by XmlHttpGetFull
/// Executes callback function in the webview with the result and validation parameters
#[command]
pub async fn xml_http_get_full(
    window: WebviewWindow,
    url_string: String,
    timeout: u64,
    post_message: Option<String>,
    method: Option<String>,
    json_headers_array: Option<String>,
    callback: String,
    check_result: i64,
    check1: Option<String>,
    check2: Option<String>,
    check3: Option<String>,
    check4: Option<String>,
    check5: Option<String>,
    call_back_success: String,
    call_back_error: Option<String>,
) -> Result<(), String> {
    let result = perform_http_request(
        &url_string,
        timeout,
        post_message,
        method,
        json_headers_array,
    )
    .await;

    let format_check = |opt: &Option<String>| -> String {
        match opt {
            Some(s) => format!("'{}'", escape_js_string(s)),
            None => "null".to_string(),
        }
    };

    let js = match result {
        Ok(response) => {
            let escaped_response = escape_js_string(&response.response_text);
            format!(
                "try {{ {}('{}', {}, {}, {}, {}, {}, {}, '{}'); }} catch(e) {{ console.error('Callback error:', e); }}",
                callback,
                escaped_response,
                check_result,
                format_check(&check1),
                format_check(&check2),
                format_check(&check3),
                format_check(&check4),
                format_check(&check5),
                call_back_success
            )
        }
        Err(_) => {
            if let Some(err_cb) = call_back_error {
                format!("try {{ {}(null); }} catch(e) {{ console.error('Error callback error:', e); }}", err_cb)
            } else {
                String::new()
            }
        }
    };

    if !js.is_empty() {
        window.eval(&js).map_err(|e| e.to_string())?;
    }
    Ok(())
}
