# Permission Scanner

The permission scanner allows scanning a DeFi protocol, or any smart contract system, for permissioned functions. It returns a list of the smart contracts, the identified permissioned functions and respective permission owners.

## How it works

In order to scan a protocol for permissioned functions, the target protocol is specified in terms of the chain and a set of addresses of all deployed contracts. These contracts all have to be verified on a public block explorer. You can find a list of supported chains and explorers [here](#supported-chains). The permission scanner then downloads the source code of the contracts from the explorer, scans these for permissions, reads the permission owner from the respective storage slot, and writes the results in an output file.

## Prerequisites

- Python3 installed on your machine
- `solc` compiler
- A valid Etherscan API key (see env variables)
- A valid Infura Project key (see env variables)

## Getting started

Create and activate a virtual Python environment, and install the required Python packages with

```shell
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Copy the `.env.example` file to `.env` and, depending on the network where the contracts are deployed on, fill in your RPC provider's url and a valid block explorer api key. Then load the variables with

```shell
source .env
```

Complete the file `./contracts.json` with the chain name and addresses of all contracts of the protocol. Find a list of supported chains [here](#supported-chains). 

Then execute the scanner script with

```shell
python src/main.py
```

Note, if you don't have the correct `solc` compiler version, it will be installed automatically by the script.

The script will write the results of the scanner in a new file `./permissions.json`.

Once you have your analysis completed, you can deactivate the Pyhton environment again with the following command

```shell
source deactivate
```

## Supported Chains

Supported chains to fetch and screen contracts from

```json
"mainnet:": (".etherscan.io", "etherscan.io")
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

## Limitations

The permission scanner does NOT guarantee that the provided set of contract addresses is complete, or that the contracts in fact are part of the protocol.

Permissions are identified by the usage of `onlyOwner` modifiers or `msg.sender` checks in a contract function. Other forms of permissions may exist that are not captured with this approach.

The permission scanner attempts to read permission owners from contract storage directly. This can fail, in particular if a contract uses an upgradeability pattern, and should be manually verified.

The permission scanner *only* identifies permissions and their owners but does not assess the impact or risks of such permissions.

## Acknowledgements

The permission scanner is built on the Slither [static analyzer](https://github.com/crytic/slither). We thank the [Trail of Bits](https://www.trailofbits.com/) team for creating this open-source tool and all the work they have done for the security in the DeFi sector.
