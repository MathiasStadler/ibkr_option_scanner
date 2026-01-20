# Create main.rs
cat > src/main.rs << 'EOF'
mod api;
mod models;
mod utils;
mod scanner;

use anyhow::{Result, Context};
use dotenv::dotenv;
use std::env;
use log::{info, error};
use std::fs;

use crate::models::scanner::ScanCriteria;
use crate::api::ibkr_client::IBKRClient;
use crate::scanner::OptionScanner;
use crate::utils::logger;

#[tokio::main]
async fn main() -> Result<()> {
    // Load environment variables
    dotenv().ok();
    logger::init_logger(true)?;
    
    info!("Starting IBKR Option Scanner");
    
    // Read configuration from environment
    let gateway_host = env::var("IBKR_GATEWAY_HOST")
        .unwrap_or_else(|_| "localhost".to_string());
    let gateway_port = env::var("IBKR_GATEWAY_PORT")
        .unwrap_or_else(|_| "5000".to_string())
        .parse::<u16>()
        .context("Invalid gateway port")?;
    let client_id = env::var("IBKR_CLIENT_ID")
        .unwrap_or_else(|_| "1".to_string())
        .parse::<i32>()
        .context("Invalid client ID")?;
    
    let target_profit_percent = env::var("TARGET_PROFIT_PERCENT")
        .unwrap_or_else(|_| "2.0".to_string())
        .parse::<f64>()
        .context("Invalid target profit percent")?;
    
    let min_volume = env::var("MIN_VOLUME")
        .unwrap_or_else(|_| "10".to_string())
        .parse::<u64>()
        .context("Invalid min volume")?;
    
    let max_dte = env::var("MAX_DTE")
        .unwrap_or_else(|_| "45".to_string())
        .parse::<i32>()
        .context("Invalid max DTE")?;
    
    let min_dte = env::var("MIN_DTE")
        .unwrap_or_else(|_| "0".to_string())
        .parse::<i32>()
        .context("Invalid min DTE")?;
    
    let symbols_file = env::var("NASDAQ_SYMBOLS_FILE")
        .unwrap_or_else(|_| "data/nasdaq_symbols.csv".to_string());
    
    let max_concurrent_requests = env::var("MAX_CONCURRENT_REQUESTS")
        .unwrap_or_else(|_| "5".to_string())
        .parse::<usize>()
        .context("Invalid max concurrent requests")?;
    
    // Create IBKR client
    let ibkr_client = IBKRClient::new(
        gateway_host,
        gateway_port,
        client_id,
    );
    
    // Create scanner
    let scanner = OptionScanner::new(ibkr_client, max_concurrent_requests);
    
    // Define scan criteria
    let criteria = ScanCriteria {
        min_profit_percent: target_profit_percent,
        max_profit_percent: Some(target_profit_percent * 2.0), // Up to 2x target
        min_volume,
        min_open_interest: 100,
        max_dte,
        min_dte,
        max_iv: Some(100.0), // Max 100% IV
        min_iv: Some(10.0),  // Min 10% IV
    };
    
    info!("Scan criteria: {:?}", criteria);
    info!("Using symbols file: {}", symbols_file);
    
    // Run scan
    let scan_result = scanner.scan_nasdaq(&symbols_file, &criteria).await?;
    
    // Display results
    display_results(&scan_result)?;
    
    // Save results to file
    save_results_to_file(&scan_result)?;
    
    Ok(())
}

fn display_results(scan_result: &crate::models::scanner::ScanResult) -> Result<()> {
    println!("\n=== OPTION SCAN RESULTS ===");
    println!("Scan Time: {}", scan_result.scan_timestamp);
    println!("Duration: {:.2} seconds", scan_result.scan_duration_seconds);
    println!("Symbols Scanned: {}", scan_result.scanned_symbols);
    println!("Total Options Scanned: ~{}", scan_result.total_options_scanned);
    println!("Opportunities Found: {}", scan_result.opportunities.len());
    println!("Target Profit: {}%", scan_result.criteria.min_profit_percent);
    println!("=".repeat(50));
    
    if scan_result.opportunities.is_empty() {
        println!("No opportunities found matching criteria.");
        return Ok(());
    }
    
    println!("TOP OPPORTUNITIES:");
    println!("{:<8} {:<6} {:<12} {:<6} {:<8} {:<8} {:<8} {:<8} {:<8}",
             "Symbol", "Type", "Expiration", "Strike", "Option$", "Stock$", "Profit%", "Volume", "IV%");
    println!("{}", "-".repeat(80));
    
    for (i, opp) in scan_result.opportunities.iter().take(20).enumerate() {
        println!("{:<8} {:<6} {:<12} {:<6.2} {:<8.2} {:<8.2} {:<8.2} {:<8} {:<8.1}",
                 opp.symbol,
                 opp.option_type,
                 opp.expiration,
                 opp.strike,
                 opp.option_price,
                 opp.stock_price,
                 opp.profit_percent,
                 opp.volume,
                 opp.implied_volatility * 100.0);
        
        if i == 9 {
            println!("... (showing top 10 of {})", scan_result.opportunities.len());
            break;
        }
    }
    
    // Show summary statistics
    if !scan_result.opportunities.is_empty() {
        let avg_profit: f64 = scan_result.opportunities.iter()
            .map(|o| o.profit_percent)
            .sum::<f64>() / scan_result.opportunities.len() as f64;
        
        let max_profit = scan_result.opportunities.iter()
            .map(|o| o.profit_percent)
            .fold(f64::MIN, |a, b| a.max(b));
        
        let min_profit = scan_result.opportunities.iter()
            .map(|o| o.profit_percent)
            .fold(f64::MAX, |a, b| a.min(b));
        
        println!("\nSUMMARY STATISTICS:");
        println!("Average Profit: {:.2}%", avg_profit);
        println!("Maximum Profit: {:.2}%", max_profit);
        println!("Minimum Profit: {:.2}%", min_profit);
        
        let calls_count = scan_result.opportunities.iter()
            .filter(|o| o.option_type == "C" || o.option_type == "CALL")
            .count();
        let puts_count = scan_result.opportunities.len() - calls_count;
        
        println!("Calls: {}, Puts: {}", calls_count, puts_count);
    }
    
    Ok(())
}

fn save_results_to_file(scan_result: &crate::models::scanner::ScanResult) -> Result<()> {
    let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S");
    let filename = format!("results/scan_results_{}.json", timestamp);
    
    // Create results directory if it doesn't exist
    fs::create_dir_all("results")?;
    
    let json = serde_json::to_string_pretty(scan_result)?;
    fs::write(&filename, json)?;
    
    println!("\nResults saved to: {}", filename);
    
    // Also save as CSV for easier analysis
    let csv_filename = format!("results/scan_results_{}.csv", timestamp);
    let mut wtr = csv::Writer::from_path(&csv_filename)?;
    
    // Write header
    wtr.write_record(&[
        "symbol", "type", "expiration", "strike", "option_price",
        "stock_price", "profit_percent", "volume", "open_interest",
        "implied_volatility", "break_even", "dte"
    ])?;
    
    // Write records
    for opp in &scan_result.opportunities {
        wtr.write_record(&[
            &opp.symbol,
            &opp.option_type,
            &opp.expiration,
            &format!("{:.2}", opp.strike),
            &format!("{:.2}", opp.option_price),
            &format!("{:.2}", opp.stock_price),
            &format!("{:.2}", opp.profit_percent),
            &format!("{}", opp.volume),
            &format!("{}", opp.open_interest),
            &format!("{:.4}", opp.implied_volatility),
            &format!("{:.2}", opp.break_even),
            &"0", // DTE would need to be calculated
        ])?;
    }
    
    wtr.flush()?;
    println!("CSV results saved to: {}", csv_filename);
    
    Ok(())
}
EOF