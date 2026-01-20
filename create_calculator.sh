# Create utils/calculator.rs
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