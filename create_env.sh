# Create .env file
echo "Creating .env.example file..."
cat > .envtouch << 'EOF'
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