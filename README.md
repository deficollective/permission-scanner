# Permission Analysis POC

## Prerequisites

- Python installed on your machine.
- A valid Etherscan API key.
- A valid Infura Project key.
- `solc` compiler

## Setup Instructions

```shell
# create virtual env
python -m venv venv
# activate virtual environment
source venv/bin/activate
# install dependencies
pip install -r requirements.txt
# deactivate venv
source deactivate
```

### .env file

See `.env.example` for the required env vars needed

## Input

Inside `list_contracts.json` the contracts of a protocol and the chain need to be specified.

Note: For chain names take from below in [Supported Networks](#supported-networks)

## Run

```shell
# specified contracts and chain from list_contracts.json
python src/main.py

# Output in result.json
```

If you don't have the correct `solc` compiler version, `solc` will install it before running the rest of the script.

## Supported Networks

Supported Networks to fetch and scan contracts from

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
