# Permission Scanner

The permission scanner allows scanning a DeFi protocol, or any smart contract system, for permissioned functions. It returns a list of the smart contracts, the identified permissioned functions and respective permission owners.

## How it works

1. In order to scan a protocol for permissioned functions, the target protocol is specified in terms of the chain and a set of addresses of all deployed contracts.
2. These contracts all have to be verified on a public block explorer.
3. You can find a list of supported chains and explorers [here](#supported-chains).
4. The permission scanner then downloads the source code of the contracts from the explorer, scans these for permissions, reads the permission owner from the respective storage slot, and writes the results in an output file.

## Prerequisites

- Python3 installed on your machine
- `solc` compiler
- A valid Etherscan API key (see env variables)
- A valid RPC api key, e.g Infura or Alchemy (see env variables)

## Getting started

### Setup Environment and dependencies

Create and activate a virtual Python environment, and install the required Python packages with

```shell
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Copy the `.env.example` file to `.env` and, depending on the network where the contracts are deployed on, fill in your RPC provider's url and a valid block explorer api key. Then load the variables with

💡 Note that etherscan migrated the API to v2, and a etherscan v2 api key, allows to query different blockchains.

```shell
source .env
```

### Create `contracts.json` file

1. Create a file called `./contracts.json`
2. Add chain name, project name
3. Add addresses to array

💡 See also the example file at `./example/contracts.json` on how to specify the input for the scanner

> If the documentation of the project you are scanning includes two addresses (proxy and implementation) just include the proxy contract address, the script will find the implementation address.

Then execute the scanner script with 🚀

```shell
python src/main.py
```

### Results

Note, if you don't have the correct `solc` compiler version, it will be installed automatically by the script with `solc_select`.

The script will write the results of the scanner in a new file `./permissions.json`. See an existing example in the example folder.

Additionally it will create a `markdown.md` which serves as a starting point to write a report for defiscan.

Once you have your analysis completed, you can deactivate the Pyhton environment again with the following command

```shell
source deactivate
```

## Supported Chains

To match `contracts.json` chain field `"Chain_Name"`, check this list. Make also sure to include a valid rpc url in the .env file.

```json
chain_ids = {
    "mainnet": 1,
    "bsc": 56,
    "poly": 137,
    "polyzk": 1101,
    "base": 8453,
    "arbi": 42161,
    "nova.arbi": 42170,
    "linea": 59144,
    "ftm": 250,
    "blast": 81457,
    "optim": 10,
    "avax": 43114,
    "bttc": 199,
    "celo": 42220,
    "cronos": 25,
    "frax": 252,
    "gno": 100,
    "kroma": 255,
    "mantle": 5000,
    "moonbeam": 1284,
    "moonriver": 1285,
    "opbnb": 204,
    "scroll": 534352,
    "taiko": 167000,
    "wemix": 1111,
    "era.zksync": 324,
    "xai": 660279,
}
```

## Limitations

The permission scanner does NOT guarantee that the provided set of contract addresses is complete, or that the contracts in fact are part of the protocol.

Permissions are identified by the usage of `onlyOwner` modifiers or `msg.sender` checks in a contract function. Other forms of permissions may exist that are not captured with this approach.

The permission scanner attempts to read permission owners from contract storage directly. This can fail, in particular if a contract uses an upgradeability pattern, and should be manually verified.

The permission scanner _only_ identifies permissions and their owners but does not assess the impact or risks of such permissions.

## Acknowledgements

The permission scanner is built on the Slither [static analyzer](https://github.com/crytic/slither). We thank the [Trail of Bits](https://www.trailofbits.com/) team for creating this open-source tool and all the work they have done for the security in the DeFi sector.
