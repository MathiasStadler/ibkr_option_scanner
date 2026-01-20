# Create models/option.rs
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