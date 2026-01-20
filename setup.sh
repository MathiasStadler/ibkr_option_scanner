#!/bin/bash
# setup.sh - Create Rust project for IBKR option scanner

set -e

PROJECT_NAME="ibkr_option_scanner"
echo "Creating Rust project: $PROJECT_NAME"

# Create project with cargo
cargo new --bin $PROJECT_NAME
cd $PROJECT_NAME

# Add dependencies to Cargo.toml
cat >> Cargo.toml << 'EOF'
[dependencies]
reqwest = { version = "0.12", features = ["json", "blocking"] }
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["full"] }
log = "0.4"
env_logger = "0.11"
chrono = { version = "0.4", features = ["serde"] }
dotenv = "0.15"
csv = "1.3"
indicatif = "0.17" # for progress bars
anyhow = "1.0"
thiserror = "1.0"

[dev-dependencies]
mockito = "1.0"
EOF

# Create directory structure
mkdir -p src/{models,api,utils}
mkdir -p config tests

# Create main source files
cat > src/models/mod.rs << 'EOF'
pub mod option;
pub mod stock;
pub mod scanner;
EOF

cat > src/api/mod.rs << 'EOF'
pub mod ibkr_client;
pub mod gateway;
EOF

cat > src/utils/mod.rs << 'EOF'
pub mod nasdaq;
pub mod calculator;
pub mod logger;
EOF

# Create .env file
cat > .env.example << 'EOF'
# IBKR Gateway Configuration
IBKR_GATEWAY_HOST=localhost
IBKR_GATEWAY_PORT=5000
IBKR_GATEWAY_VERSION=v1

# API Settings
IBKR_CLIENT_ID=1
IBKR_ACCOUNT_ID=your_account_id

# Scanner Settings
TARGET_PROFIT_PERCENT=2.0
MIN_VOLUME=10
MAX_DTE=45
MIN_DTE=0

# NASDAQ Settings
NASDAQ_SYMBOLS_FILE=data/nasdaq_symbols.csv
MAX_CONCURRENT_REQUESTS=5
EOF

# Create data directory and sample symbols
mkdir -p data
cat > data/nasdaq_symbols_sample.csv << 'EOF'
Symbol,Name,Last Sale,Net Change,Percent Change,Market Cap,Country,IPO Year,Volume,Sector,Industry
AAPL,Apple Inc.,150.00,+1.50,+1.01%,2.5T,USA,1980,50000000,Technology,Computer Hardware
GOOGL,Alphabet Inc.,100.00,+0.50,+0.50%,1.3T,USA,2004,25000000,Technology,Internet
MSFT,Microsoft Corporation,250.00,+2.00,+0.81%,1.9T,USA,1986,30000000,Technology,Software
AMZN,Amazon.com Inc.,110.00,+1.00,+0.92%,1.1T,USA,1997,40000000,Consumer Cyclical,Internet Retail
TSLA,Tesla Inc.,180.00,+3.00,+1.69%,570B,USA,2010,80000000,Consumer Cyclical,Auto Manufacturers
META, Meta Platforms Inc.,230.00,+2.50,+1.10%,590B,USA,2012,20000000,Technology,Internet
NVDA,NVIDIA Corporation,300.00,+5.00,+1.69%,740B,USA,1999,25000000,Technology,Semiconductors
EOF

# Create models
cat > src/models/stock.rs << 'EOF'
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Stock {
    pub symbol: String,
    pub name: String,
    pub last_price: f64,
    pub market_cap: String,
    pub sector: String,
    pub industry: String,
    pub volume: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StockQuote {
    pub symbol: String,
    pub price: f64,
    pub change: f64,
    pub change_percent: f64,
    pub volume: u64,
    pub timestamp: String,
}
EOF

cat > src/models/option.rs << 'EOF'
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptionContract {
    pub symbol: String,
    pub strike: f64,
    pub expiration: String,
    pub option_type: String, // "CALL" or "PUT"
    pub last_price: f64,
    pub bid: f64,
    pub ask: f64,
    pub volume: u64,
    pub open_interest: u64,
    pub implied_volatility: f64,
    pub delta: f64,
    pub gamma: f64,
    pub theta: f64,
    pub vega: f64,
    pub dte: i32, // Days to expiration
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptionChain {
    pub stock_symbol: String,
    pub stock_price: f64,
    pub expiration_date: String,
    pub calls: Vec<OptionContract>,
    pub puts: Vec<OptionContract>,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptionOpportunity {
    pub symbol: String,
    pub strike: f64,
    pub expiration: String,
    pub option_type: String,
    pub option_price: f64,
    pub stock_price: f64,
    pub profit_percent: f64,
    pub volume: u64,
    pub open_interest: u64,
    pub implied_volatility: f64,
    pub break_even: f64,
    pub max_profit: Option<f64>,
    pub max_loss: Option<f64>,
    pub risk_reward_ratio: Option<f64>,
}
EOF

cat > src/models/scanner.rs << 'EOF'
use serde::{Deserialize, Serialize};
use super::option::OptionOpportunity;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanCriteria {
    pub min_profit_percent: f64,
    pub max_profit_percent: Option<f64>,
    pub min_volume: u64,
    pub min_open_interest: u64,
    pub max_dte: i32,
    pub min_dte: i32,
    pub max_iv: Option<f64>,
    pub min_iv: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanResult {
    pub criteria: ScanCriteria,
    pub opportunities: Vec<OptionOpportunity>,
    pub scanned_symbols: usize,
    pub total_options_scanned: usize,
    pub scan_timestamp: chrono::DateTime<chrono::Utc>,
    pub scan_duration_seconds: f64,
}
EOF

# Create API client
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
        let endpoint = format!("api/iserver/marketdata/snapshot?conids={}", self.get_conid(symbol)?);
        
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
        let endpoint = format!(
            "api/iserver/secdef/strikes?conid={}&secType=OPT",
            self.get_conid(symbol)?
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

# Create utils
cat > src/utils/nasdaq.rs << 'EOF'
use std::fs::File;
use std::io::{BufReader, BufRead};
use anyhow::{Result, Context};
use crate::models::stock::Stock;
use log::{info, warn};

pub struct NasdaqLoader;

impl NasdaqLoader {
    pub fn load_symbols_from_file(filepath: &str) -> Result<Vec<String>> {
        let file = File::open(filepath)
            .with_context(|| format!("Failed to open symbols file: {}", filepath))?;
        
        let reader = BufReader::new(file);
        let mut symbols = Vec::new();
        
        for (i, line) in reader.lines().enumerate() {
            let line = line?;
            
            // Skip header
            if i == 0 {
                continue;
            }
            
            let parts: Vec<&str> = line.split(',').collect();
            if parts.len() > 1 {
                let symbol = parts[0].trim().to_string();
                if !symbol.is_empty() {
                    symbols.push(symbol);
                }
            }
        }
        
        info!("Loaded {} symbols from {}", symbols.len(), filepath);
        Ok(symbols)
    }
    
    pub fn load_symbols_with_details(filepath: &str) -> Result<Vec<Stock>> {
        let file = File::open(filepath)
            .with_context(|| format!("Failed to open symbols file: {}", filepath))?;
        
        let reader = BufReader::new(file);
        let mut stocks = Vec::new();
        
        for (i, line) in reader.lines().enumerate() {
            let line = line?;
            
            // Skip header
            if i == 0 {
                continue;
            }
            
            let parts: Vec<&str> = line.split(',').collect();
            if parts.len() >= 11 {
                let stock = Stock {
                    symbol: parts[0].trim().to_string(),
                    name: parts[1].trim().to_string(),
                    last_price: parts[2].trim().parse().unwrap_or(0.0),
                    market_cap: parts[5].trim().to_string(),
                    sector: parts[9].trim().to_string(),
                    industry: parts[10].trim().to_string(),
                    volume: parts[8].trim().parse().unwrap_or(0),
                };
                stocks.push(stock);
            }
        }
        
        info!("Loaded {} stocks with details from {}", stocks.len(), filepath);
        Ok(stocks)
    }
    
    pub fn filter_by_market_cap(stocks: Vec<Stock>, min_market_cap_billion: f64) -> Vec<Stock> {
        stocks.into_iter()
            .filter(|stock| {
                let market_cap_str = stock.market_cap.to_lowercase();
                if market_cap_str.ends_with('t') {
                    market_cap_str.trim_end_matches('t').parse::<f64>().unwrap_or(0.0) >= min_market_cap_billion / 1000.0
                } else if market_cap_str.ends_with('b') {
                    market_cap_str.trim_end_matches('b').parse::<f64>().unwrap_or(0.0) >= min_market_cap_billion
                } else {
                    false
                }
            })
            .collect()
    }
    
    pub fn filter_by_sector(stocks: Vec<Stock>, allowed_sectors: &[&str]) -> Vec<Stock> {
        if allowed_sectors.is_empty() {
            return stocks;
        }
        
        stocks.into_iter()
            .filter(|stock| allowed_sectors.contains(&stock.sector.as_str()))
            .collect()
    }
    
    pub fn filter_by_volume(stocks: Vec<Stock>, min_volume: u64) -> Vec<Stock> {
        stocks.into_iter()
            .filter(|stock| stock.volume >= min_volume)
            .collect()
    }
}
EOF

cat > src/utils/calculator.rs << 'EOF'
use crate::models::option::{OptionContract, OptionOpportunity};

pub struct OptionCalculator;

impl OptionCalculator {
    pub fn calculate_profit_percentage(strike: f64, option_price: f64, stock_price: f64) -> f64 {
        if option_price <= 0.0 || strike <= 0.0 {
            return 0.0;
        }
        
        // For calls: profit% = (strike - stock_price - option_price) / option_price * 100
        // But we want to find opportunities where option is underpriced relative to strike
        
        // Simplified: Compare strike to option price
        // A higher strike/option price ratio might indicate opportunity
        let ratio = strike / option_price;
        
        // Normalize based on stock price
        let normalized_ratio = ratio * (option_price / stock_price);
        normalized_ratio * 100.0
    }
    
    pub fn find_profitable_options(
        options: &[OptionContract],
        stock_price: f64,
        min_profit_percent: f64,
        min_volume: u64,
        min_dte: i32,
        max_dte: i32,
    ) -> Vec<OptionOpportunity> {
        let mut opportunities = Vec::new();
        
        for option in options {
            // Filter by criteria
            if option.volume < min_volume {
                continue;
            }
            
            if option.dte < min_dte || option.dte > max_dte {
                continue;
            }
            
            let profit_percent = Self::calculate_profit_percentage(
                option.strike,
                option.last_price,
                stock_price,
            );
            
            if profit_percent >= min_profit_percent {
                let break_even = Self::calculate_break_even(
                    option.strike,
                    option.last_price,
                    &option.option_type,
                );
                
                let (max_profit, max_loss) = Self::calculate_max_profit_loss(
                    option.strike,
                    option.last_price,
                    stock_price,
                    &option.option_type,
                );
                
                let risk_reward_ratio = if let (Some(profit), Some(loss)) = (max_profit, max_loss) {
                    if loss != 0.0 {
                        Some(profit / loss)
                    } else {
                        None
                    }
                } else {
                    None
                };
                
                opportunities.push(OptionOpportunity {
                    symbol: option.symbol.clone(),
                    strike: option.strike,
                    expiration: option.expiration.clone(),
                    option_type: option.option_type.clone(),
                    option_price: option.last_price,
                    stock_price,
                    profit_percent,
                    volume: option.volume,
                    open_interest: option.open_interest,
                    implied_volatility: option.implied_volatility,
                    break_even,
                    max_profit,
                    max_loss,
                    risk_reward_ratio,
                });
            }
        }
        
        opportunities
    }
    
    pub fn calculate_break_even(strike: f64, option_price: f64, option_type: &str) -> f64 {
        match option_type {
            "C" | "CALL" => strike + option_price,
            "P" | "PUT" => strike - option_price,
            _ => 0.0,
        }
    }
    
    pub fn calculate_max_profit_loss(
        strike: f64,
        option_price: f64,
        stock_price: f64,
        option_type: &str,
    ) -> (Option<f64>, Option<f64>) {
        match option_type {
            "C" | "CALL" => {
                // For long call: max profit unlimited, max loss = option price
                (None, Some(option_price))
            }
            "P" | "PUT" => {
                // For long put: max profit = strike - option price, max loss = option price
                (Some(strike - option_price), Some(option_price))
            }
            _ => (None, None),
        }
    }
    
    pub fn calculate_implied_movement(
        implied_volatility: f64,
        dte: i32,
        stock_price: f64,
    ) -> f64 {
        // Calculate expected move based on IV
        // Expected move = stock_price * IV * sqrt(dte/365)
        stock_price * implied_volatility * (dte as f64 / 365.0).sqrt()
    }
}
EOF

cat > src/utils/logger.rs << 'EOF'
use log::{LevelFilter, SetLoggerError};
use env_logger::Builder;
use std::io::Write;

pub fn init_logger(verbose: bool) -> Result<(), SetLoggerError> {
    let level = if verbose {
        LevelFilter::Debug
    } else {
        LevelFilter::Info
    };
    
    Builder::new()
        .format(|buf, record| {
            writeln!(
                buf,
                "[{} {}] {}",
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                record.args()
            )
        })
        .filter(None, level)
        .init();
    
    Ok(())
}
EOF

# Create main scanner
cat > src/scanner.rs << 'EOF'
use std::time::Instant;
use tokio::sync::Semaphore;
use std::sync::Arc;
use tokio::task;
use indicatif::{ProgressBar, ProgressStyle};
use anyhow::{Result, Context};
use log::{info, warn, error};

use crate::api::ibkr_client::IBKRClient;
use crate::models::scanner::{ScanCriteria, ScanResult};
use crate::models::option::OptionOpportunity;
use crate::utils::calculator::OptionCalculator;
use crate::utils::nasdaq::NasdaqLoader;

pub struct OptionScanner {
    client: IBKRClient,
    max_concurrent: usize,
}

impl OptionScanner {
    pub fn new(client: IBKRClient, max_concurrent: usize) -> Self {
        OptionScanner {
            client,
            max_concurrent,
        }
    }

    pub async fn scan_nasdaq(
        &self,
        symbols_file: &str,
        criteria: &ScanCriteria,
    ) -> Result<ScanResult> {
        info!("Starting NASDAQ options scan with criteria: {:?}", criteria);
        let start_time = Instant::now();
        
        // Load NASDAQ symbols
        let symbols = NasdaqLoader::load_symbols_from_file(symbols_file)
            .with_context(|| format!("Failed to load symbols from {}", symbols_file))?;
        
        info!("Loaded {} symbols to scan", symbols.len());
        
        // Create progress bar
        let pb = ProgressBar::new(symbols.len() as u64);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta}) {msg}")
                .unwrap()
                .progress_chars("#>-"),
        );
        
        // Semaphore to limit concurrent requests
        let semaphore = Arc::new(Semaphore::new(self.max_concurrent));
        let mut tasks = Vec::new();
        let mut all_opportunities = Vec::new();
        let mut scanned_count = 0;
        let mut error_count = 0;
        
        for symbol in symbols {
            let permit = semaphore.clone().acquire_owned().await?;
            let client = self.client.clone();
            let criteria = criteria.clone();
            let pb = pb.clone();
            
            let task = task::spawn(async move {
                let _permit = permit;
                let result = Self::scan_symbol(&client, &symbol, &criteria).await;
                pb.inc(1);
                pb.set_message(format!("Scanning {}...", symbol));
                result
            });
            
            tasks.push((symbol, task));
        }
        
        // Collect results
        for (symbol, task) in tasks {
            match task.await {
                Ok(Ok(Some(opportunities))) => {
                    if !opportunities.is_empty() {
                        info!("Found {} opportunities for {}", opportunities.len(), symbol);
                        all_opportunities.extend(opportunities);
                    }
                    scanned_count += 1;
                }
                Ok(Ok(None)) => {
                    scanned_count += 1;
                }
                Ok(Err(e)) => {
                    warn!("Error scanning {}: {}", symbol, e);
                    error_count += 1;
                }
                Err(e) => {
                    error!("Task error for {}: {}", symbol, e);
                    error_count += 1;
                }
            }
        }
        
        pb.finish_with_message("Scan complete!");
        
        let scan_duration = start_time.elapsed();
        
        // Sort opportunities by profit percentage (descending)
        all_opportunities.sort_by(|a, b| {
            b.profit_percent.partial_cmp(&a.profit_percent).unwrap()
        });
        
        let result = ScanResult {
            criteria: criteria.clone(),
            opportunities: all_opportunities,
            scanned_symbols: scanned_count,
            total_options_scanned: scanned_count * 2, // Approximate
            scan_timestamp: chrono::Utc::now(),
            scan_duration_seconds: scan_duration.as_secs_f64(),
        };
        
        info!(
            "Scan completed in {:.2} seconds. Scanned {} symbols ({} errors). Found {} opportunities.",
            scan_duration.as_secs_f64(),
            scanned_count,
            error_count,
            result.opportunities.len()
        );
        
        Ok(result)
    }
    
    async fn scan_symbol(
        client: &IBKRClient,
        symbol: &str,
        criteria: &ScanCriteria,
    ) -> Result<Option<Vec<OptionOpportunity>>> {
        // Get option chain
        let option_chain = match client.get_option_chain(symbol, None).await {
            Ok(chain) => chain,
            Err(e) => {
                warn!("Failed to get option chain for {}: {}", symbol, e);
                return Ok(None);
            }
        };
        
        // Find profitable calls
        let profitable_calls = OptionCalculator::find_profitable_options(
            &option_chain.calls,
            option_chain.stock_price,
            criteria.min_profit_percent,
            criteria.min_volume,
            criteria.min_dte,
            criteria.max_dte,
        );
        
        // Find profitable puts
        let profitable_puts = OptionCalculator::find_profitable_options(
            &option_chain.puts,
            option_chain.stock_price,
            criteria.min_profit_percent,
            criteria.min_volume,
            criteria.min_dte,
            criteria.max_dte,
        );
        
        // Combine results
        let mut opportunities = Vec::new();
        opportunities.extend(profitable_calls);
        opportunities.extend(profitable_puts);
        
        if opportunities.is_empty() {
            Ok(None)
        } else {
            Ok(Some(opportunities))
        }
    }
}
EOF