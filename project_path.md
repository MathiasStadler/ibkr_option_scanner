# generate from prompt

## change to /tmp

cd /tmp

## delete

rm -rf /tmp/ibkr_option_scanner

## execute scripts

sh +x /home/trapapa/ibkr_option_scanner_setup/create_cargo.sh && \
cd /tmp/ibkr_option_scanner && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_env.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_api_mod.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_calculator.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_gateway.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_ibkr_client.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_looger.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_mod.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_models_mod.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_nasdaq.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_option.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_scanner.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_stock.sh && \
sh +x /home/trapapa/ibkr_option_scanner_setup/create_main.sh
