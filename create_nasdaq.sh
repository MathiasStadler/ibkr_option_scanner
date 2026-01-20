# Create utils/nasdaq.rs
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
                continue;# Create utils/nasdaq.rs
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
                    false# Create utils/nasdaq.rs
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