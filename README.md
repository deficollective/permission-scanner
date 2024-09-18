# Permission Analysis POC

## Prerequisites

- Python installed on your machine.
- A valid Etherscan API key.
- A valid Infura Project key.

## Setup Instructions

```shell
# create virtual env
python -m venv venv
# activate virtual environment
source venv/bin/activate
# install dependencies
pip install -r requirements.txt
# install & select solc compiler
solc-select install 0.8.20
solc-select use 0.8.20
# deactivate venv
source deactivate
```

### .env file

See `.env.example` for the required env vars needed

## Run

### scan one address

```shell
# specify contracts to be scanned inside list_contracts.json
# specify the chain where the platform is based on in the same json.
python src/main.py

# Output in result.json
```

## Filter Contracts

Supported Networks to fetch contracts from

```json
"mainet:": (".etherscan.io", "etherscan.io")
"optim:": ("-optimistic.etherscan.io", "optimistic.etherscan.io")
"goerli:": ("-goerli.etherscan.io", "goerli.etherscan.io")
"sepolia:": ("-sepolia.etherscan.io", "sepolia.etherscan.io")
"tobalaba:": ("-tobalaba.etherscan.io", "tobalaba.etherscan.io")
"bsc:": (".bscscan.com", "bscscan.com")
"testnet.bsc:": ("-testnet.bscscan.com", "testnet.bscscan.com")
"arbi:": (".arbiscan.io", "arbiscan.io")
"testnet.arbi:": ("-testnet.arbiscan.io", "testnet.arbiscan.io")
"poly:": (".polygonscan.com", "polygonscan.com")
"mumbai:": ("-testnet.polygonscan.com", "testnet.polygonscan.com")
"avax:": (".snowtrace.io", "snowtrace.io")
"testnet.avax:": ("-testnet.snowtrace.io", "testnet.snowtrace.io")
"ftm:": (".ftmscan.com", "ftmscan.com")
"goerli.base:": ("-goerli.basescan.org", "goerli.basescan.org")
"base:": (".basescan.org", "basescan.org")
"gno:": (".gnosisscan.io", "gnosisscan.io")
"polyzk:": ("-zkevm.polygonscan.com", "zkevm.polygonscan.com")
"blast:": (".blastscan.io", "blastscan.io")
```
