#!/bin/bash
# setup.sh - Create Rust project for IBKR option scanner

set -e

PROJECT_NAME="ibkr_option_scanner"
echo "Creating Rust project: $PROJECT_NAME"

# Create project with cargo
cargo new --bin $PROJECT_NAME
cd $PROJECT_NAME

# Create directory structure FIRST
echo "Creating directory structure..."
mkdir -p src/{models,api,utils}
mkdir -p config tests data results

# Now add dependencies to Cargo.toml
echo "Adding dependencies to Cargo.toml..."


# Create directory structure FIRST
echo "Creating directory structure..."
mkdir -p src/{models,api,utils}
mkdir -p config tests data results

# Now add dependencies to Cargo.toml
echo "Adding dependencies to Cargo.toml..."
cat >> Cargo.toml << 'EOF'
[dependencies]
reqwest = { version = "0.12", features = ["json", "blocking"] }
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
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