# Create api/mod.rs
cat > src/api/mod.rs << 'EOF'
pub mod ibkr_client;
pub mod gateway;
EOF

# Create utils/mod.rs
cat > src/utils/mod.rs << 'EOF'
pub mod nasdaq;
pub mod calculator;
pub mod logger;
EOFmv 