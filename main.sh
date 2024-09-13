#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Check if the required environment variables are set
if [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$INFURA_KEY" ]; then
  echo "Please ensure ETHERSCAN_API_KEY and INFURA_KEY are set in the .env file."
  exit 1
fi

# Check if at least one address is passed
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <address1> <address2> ... <addressN>"
  exit 1
fi

# Loop through all provided addresses
for address in "$@"
do
  echo "Executing script for address: $address"
  python src/main.py "$address" --etherscan-apikey="$ETHERSCAN_API_KEY" --rpc-url="https://mainnet.infura.io/v3/$INFURA_KEY"
done
