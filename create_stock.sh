# Create models/stock.rs
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