# Create api/ibkr_client.rs
cat > src/api/ibkr_client.rs << 'EOF'
use std::collections::HashMap;
use anyhow::{Result, Context};
use serde_json::Value;
use log::{info, warn, error};
use crate::models::option::{OptionChain, OptionContract};
use crate::models::stock::StockQuote;
use super::gateway::GatewayClient;

#[derive(Clone)]
pub struct IBKRClient {
    gateway: GatewayClient,
    client_id: i32,
}

impl IBKRClient {
    pub fn new(host: String, port: u16, client_id: i32) -> Self {
        IBKRClient {
            gateway: GatewayClient::new(host, port),
            client_id,
        }
    }

    pub async fn get_stock_quote(&self, symbol: &str) -> Result<StockQuote> {
        let conid = self.get_conid(symbol)?;
        let endpoint = format!("api/iserver/marketdata/snapshot?conids={}", conid);
        
        let response = self.gateway.get(&endpoint).await
            .with_context(|| format!("Failed to get quote for {}", symbol))?;
        
        let json: Value = serde_json::from_str(&response)?;
        
        Ok(StockQuote {
            symbol: symbol.to_string(),
            price: json["31"].as_f64().unwrap_or(0.0),
            change: json["70"].as_f64().unwrap_or(0.0),
            change_percent: json["71"].as_f64().unwrap_or(0.0),
            volume: json["72"].as_f64().unwrap_or(0.0) as u64,
            timestamp: chrono::Utc::now().to_rfc3339(),
        })
    }

    pub async fn get_option_chain(&self, symbol: &str, expiration: Option<&str>) -> Result<OptionChain> {
        let stock_quote = self.get_stock_quote(symbol).await?;
        
        // Get expirations first
        let expirations = self.get_option_expirations(symbol).await?;
        if expirations.is_empty() {
            return Err(anyhow::anyhow!("No option expirations found for {}", symbol));
        }
        
        let target_expiration = expiration.unwrap_or(&expirations[0]);
        
        // Get option chain for expiration
        let endpoint = format!(
            "api/iserver/secdef/search?symbol={}&secType=OPT&exchange=SMART",
            symbol
        );
        
        let response = self.gateway.get(&endpoint).await
            .with_context(|| format!("Failed to get option chain for {}", symbol))?;
        
        let options = self.parse_option_chain_response(&response, symbol, target_expiration, stock_quote.price).await?;
        
        Ok(OptionChain {
            stock_symbol: symbol.to_string(),
            stock_price: stock_quote.price,
            expiration_date: target_expiration.to_string(),
            calls: options.0,
            puts: options.1,
            timestamp: chrono::Utc::now(),
        })
    }

    async fn get_option_expirations(&self, symbol: &str) -> Result<Vec<String>> {
        let conid = self.get_conid(symbol)?;
        let endpoint = format!(
            "api/iserver/secdef/strikes?conid={}&secType=OPT",
            conid
        );
        
        let response = self.gateway.get(&endpoint).await
            .with_context(|| format!("Failed to get expirations for {}", symbol))?;
        
        let json: Value = serde_json::from_str(&response)?;
        let expirations: Vec<String> = json["call"]["expirations"]
            .as_array()
            .unwrap_or(&vec![])
            .iter()
            .filter_map(|v| v.as_str().map(|s| s.to_string()))
            .collect();
        
        Ok(expirations)
    }

    async fn parse_option_chain_response(
        &self,
        response: &str,
        symbol: &str,
        expiration: &str,
        stock_price: f64
    ) -> Result<(Vec<OptionContract>, Vec<OptionContract>)> {
        let json: Value = serde_json::from_str(response)?;
        let mut calls = Vec::new();
        let mut puts = Vec::new();
        
        if let Some(contracts) = json.as_array() {
            for contract in contracts {
                let conid = contract["conid"].as_str().unwrap_or("").to_string();
                
                // Get option details
                if let Ok(details) = self.get_option_details(&conid).await {
                    let strike = contract["strike"].as_f64().unwrap_or(0.0);
                    let option_type = contract["right"].as_str().unwrap_or("").to_string();
                    
                    let option_contract = OptionContract {
                        symbol: symbol.to_string(),
                        strike,
                        expiration: expiration.to_string(),
                        option_type: option_type.clone(),
                        last_price: details.0,
                        bid: details.1,
                        ask: details.2,
                        volume: details.3,
                        open_interest: details.4,
                        implied_volatility: details.5,
                        delta: details.6,
                        gamma: details.7,
                        theta: details.8,
                        vega: details.9,
                        dte: self.calculate_dte(expiration),
                    };
                    
                    if option_type == "C" {
                        calls.push(option_contract);
                    } else {
                        puts.push(option_contract);
                    }
                }
            }
        }
        
        Ok((calls, puts))
    }

    async fn get_option_details(&self, conid: &str) -> Result<(f64, f64, f64, u64, u64, f64, f64, f64, f64, f64)> {
        let endpoint = format!("api/iserver/marketdata/snapshot?conids={}", conid);
        
        let response = self.gateway.get(&endpoint).await
            .with_context(|| format!("Failed to get option details for conid {}", conid))?;
        
        let json: Value = serde_json::from_str(&response)?;
        
        Ok((
            json["31"].as_f64().unwrap_or(0.0), // last
            json["76"].as_f64().unwrap_or(0.0), // bid
            json["86"].as_f64().unwrap_or(0.0), // ask
            json["72"].as_f64().unwrap_or(0.0) as u64, // volume
            json["44"].as_f64().unwrap_or(0.0) as u64, // open interest
            json["101"].as_f64().unwrap_or(0.0), // implied vol
            json["58"].as_f64().unwrap_or(0.0), // delta
            json["59"].as_f64().unwrap_or(0.0), // gamma
            json["60"].as_f64().unwrap_or(0.0), // theta
            json["61"].as_f64().unwrap_or(0.0), // vega
        ))
    }

    fn get_conid(&self, symbol: &str) -> Result<String> {
        // In a real implementation, you would have a mapping or API call to get CONID
        // For common NASDAQ stocks, we can use a simple mapping
        let conid_map: HashMap<&str, &str> = [
            ("AAPL", "265598"),
            ("GOOGL", "208813719"),
            ("MSFT", "272093"),
            ("AMZN", "3691937"),
            ("TSLA", "76792991"),
            ("META", "107113172"),
            ("NVDA", "4815747"),
        ].iter().cloned().collect();
        
        conid_map.get(symbol)
            .map(|s| s.to_string())
            .ok_or_else(|| anyhow::anyhow!("CONID not found for symbol: {}", symbol))
    }

    fn calculate_dte(&self, expiration: &str) -> i32 {
        // Parse expiration string (assuming format like "20241220")
        if let Ok(exp_date) = chrono::NaiveDate::parse_from_str(expiration, "%Y%m%d") {
            let today = chrono::Utc::now().naive_utc().date();
            (exp_date - today).num_days() as i32
        } else {
            0
        }
    }
}
EOF