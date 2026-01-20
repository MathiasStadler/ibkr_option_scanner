# Create api/gateway.rs
cat > src/api/gateway.rs << 'EOF'
use anyhow::{Result, Context};
use std::time::Duration;
use reqwest::Client;
use log::{info, warn};

#[derive(Clone)]
pub struct GatewayClient {
    base_url: String,
    client: Client,
}

impl GatewayClient {
    pub fn new(host: String, port: u16) -> Self {
        GatewayClient {
            base_url: format!("https://{}:{}/", host, port),
            client: Client::builder()
                .timeout(Duration::from_secs(30))
                .danger_accept_invalid_certs(true) // For self-signed certs in gateway
                .build()
                .expect("Failed to create HTTP client"),
        }
    }

    pub async fn get(&self, endpoint: &str) -> Result<String> {
        let url = format!("{}{}", self.base_url, endpoint);
        info!("Making GET request to: {}", url);
        
        let response = self.client
            .get(&url)
            .header("accept", "application/json")# Create api/gateway.rs
cat > src/api/gateway.rs << 'EOF'
use anyhow::{Result, Context};
use std::time::Duration;
use reqwest::Client;
use log::{info, warn};

#[derive(Clone)]
pub struct GatewayClient {
    base_url: String,
    client: Client,
}

impl GatewayClient {
    pub fn new(host: String, port: u16) -> Self {
        GatewayClient {
            base_url: format!("https://{}:{}/", host, port),
            client: Client::builder()
                .timeout(Duration::from_secs(30))
                .danger_accept_invalid_certs(true) // For self-signed certs in gateway
                .build()
                .expect("Failed to create HTTP client"),
        }
    }

    pub async fn get(&self, endpoint: &str) -> Result<String> {
        let url = format!("{}{}", self.base_url, endpoint);
        info!("Making GET request to: {}", url);
        
        let response = self.client
            .get(&url)
            .header("accept", "application/json")
            .send()
            .await
            .with_context(|| format!("Failed to send request to {}", url))?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await.unwrap_or_default();
            warn!("Request failed with status {}: {}", status, text);
            return Err(anyhow::anyhow!("HTTP {}: {}", status, text));
        }
        
        response.text()
            .await
            .with_context(|| format!("Failed to read response from {}", url))
    }

    pub async fn post(&self, endpoint: &str, body: &str) -> Result<String> {
        let url = format!("{}{}", self.base_url, endpoint);
        info!("Making POST request to: {}", url);
        
        let response = self.client
            .post(&url)
            .header("accept", "application/json")
            .header("content-type", "application/json")
            .body(body.to_string())
            .send()
            .await
            .with_context(|| format!("Failed to send request to {}", url))?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await.unwrap_or_default();
            warn!("Request failed with status {}: {}", status, text);
            return Err(anyhow::anyhow!("HTTP {}: {}", status, text));
        }
        
        response.text()
            .await
            .with_context(|| format!("Failed to read response from {}", url))
    }
}
EOF
            