# Create models/scanner.rs
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
touch EOF