# Create utils/logger.rs
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