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

Create env file with the following keys

```
ETHERSCAN_API_KEY=your_etherscan_api_key
INFURA_KEY=your_infura_project_key
```

## Run

### scan one address

```shell
# specify contracts to be scanned inside list_contracts.json
python src/main.py

# Output in result.json
```
