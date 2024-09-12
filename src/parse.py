from crytic_compile import cryticparser
import argparse

def parse_args() -> argparse.Namespace:
    """Parse the underlying arguments for the program.
    Returns:
        The arguments for the program.
    """
    parser = argparse.ArgumentParser(
        description="Read a variable's value from storage for a deployed contract",
        usage=(
            "\nTo retrieve a single variable's value:\n"
            + "\tslither-read-storage $TARGET address --variable-name $NAME\n"
            + "To retrieve a contract's storage layout:\n"
            + "\tslither-read-storage $TARGET address --contract-name $NAME --json storage_layout.json\n"
            + "To retrieve a contract's storage layout and values:\n"
            + "\tslither-read-storage $TARGET address --contract-name $NAME --json storage_layout.json --value\n"
            + "TARGET can be a contract address or project directory"
        ),
    )

    parser.add_argument(
        "contract_source",
        help="The deployed contract address if verified on etherscan. Prepend project directory for unverified contracts.",
        nargs="+",
    )

    parser.add_argument(
        "--variable-name",
        help="The name of the variable whose value will be returned.",
        default=None,
    )

    parser.add_argument("--rpc-url", help="An endpoint for web3 requests.")

    parser.add_argument(
        "--key",
        help="The key/ index whose value will be returned from a mapping or array.",
        default=None,
    )

    parser.add_argument(
        "--deep-key",
        help="The key/ index whose value will be returned from a deep mapping or multidimensional array.",
        default=None,
    )

    parser.add_argument(
        "--struct-var",
        help="The name of the variable whose value will be returned from a struct.",
        default=None,
    )

    parser.add_argument(
        "--storage-address",
        help="The address of the storage contract (if a proxy pattern is used).",
        default=None,
    )

    parser.add_argument(
        "--contract-name",
        help="The name of the logic contract.",
        default=None,
    )

    parser.add_argument(
        "--json",
        action="store",
        help="Save the result in a JSON file.",
    )

    parser.add_argument(
        "--value",
        action="store_true",
        help="Toggle used to include values in output.",
    )

    parser.add_argument(
        "--table",
        action="store_true",
        help="Print table view of storage layout",
    )

    parser.add_argument(
        "--silent",
        action="store_true",
        help="Silence log outputs",
    )

    parser.add_argument("--max-depth", help="Max depth to search in data structure.", default=20)

    parser.add_argument(
        "--block",
        help="The block number to read storage from. Requires an archive node to be provided as the RPC url.",
        default="latest",
    )

    parser.add_argument(
        "--unstructured",
        action="store_true",
        help="Include unstructured storage slots",
    )

    cryticparser.init(parser)

    return parser.parse_args()