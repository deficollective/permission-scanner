from crytic_compile import cryticparser
import argparse
import os

def init_args(contract_address: str) -> argparse.Namespace:
    """Parse the underlying arguments for the program.
    Returns:
        The arguments for the program.
    """

    # create a ArgumentParser for cryticparser.init
    parser = argparse.ArgumentParser(
        description="Read a variable's value from storage for a deployed contract",
        usage=("\nProvide secrets in env file\n"),
    )

    # Add arguments (this step is required before setting defaults)
    parser.add_argument("--contract_source", nargs="+", help="Contract address or project directory")
    parser.add_argument("--rpc-url", help="RPC endpoint URL")
    parser.add_argument("--etherscan-api-key", help="Etherscan API key")
    parser.add_argument("--max-depth", help="Max depth to search in data structure.", default=20)
    parser.add_argument(
        "--block",
        help="The block number to read storage from. Requires an archive node to be provided as the RPC url.",
        default="latest",
    )


    # Set defaults for arguments programmatically
    # Hyphens (-) in argument names are automatically converted to underscores (_)
    parser.set_defaults(
        contract_source=contract_address,
        rpc_url=f'https://mainnet.infura.io/v3/{os.getenv("INFURA_KEY")}',
        etherscan_api_key=os.getenv("ETHERSCAN_API_KEY"),
    )

    # requires a ArgumentParser instance
    cryticparser.init(parser)

    return parser.parse_args()