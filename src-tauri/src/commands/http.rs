use serde::{Deserialize, Serialize};
use tauri::command;
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

/// Async HTTP - returns response for JavaScript to handle callbacks
#[command]
pub async fn base_xml_http_get(
    url_string: String,
    timeout: u64,
    post_message: Option<String>,
    method: Option<String>,
    json_headers_array: Option<String>,
) -> Result<HttpResponse, String> {
    perform_http_request(
        &url_string,
        timeout,
        post_message,
        method,
        json_headers_array,
    )
    .await
}

/// Full async HTTP - returns response for JavaScript to handle callbacks
#[command]
pub async fn xml_http_get_full(
    url_string: String,
    timeout: u64,
    post_message: Option<String>,
    method: Option<String>,
    json_headers_array: Option<String>,
) -> Result<HttpResponse, String> {
    perform_http_request(
        &url_string,
        timeout,
        post_message,
        method,
        json_headers_array,
    )
    .await
}

/// Binary response for video segments
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct BinaryHttpResponse {
    pub status: u16,
    pub data: Vec<u8>,
}

/// Fetch binary data (for HLS video segments)
#[command]
pub async fn fetch_binary(
    url: String,
    timeout: u64,
) -> Result<BinaryHttpResponse, String> {
    let client = reqwest::Client::new();

    let request = client
        .get(&url)
        .timeout(Duration::from_millis(timeout.max(1000)));

    match request.send().await {
        Ok(response) => {
            let status = response.status().as_u16();
            let bytes = response.bytes().await.map_err(|e| e.to_string())?;

            Ok(BinaryHttpResponse {
                status,
                data: bytes.to_vec(),
            })
        }
        Err(e) => {
            Ok(BinaryHttpResponse {
                status: 0,
                data: e.to_string().into_bytes(),
            })
        }
    }
}
