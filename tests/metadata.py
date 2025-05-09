from slither import Slither
from permission_scanner import ContractScanner, BlockExplorer
import os
from dotenv import load_dotenv

load_dotenv()


def main():
    # Setup environment variables
    api_key = os.getenv("ETHERSCAN_API_KEY")
    rpc_url = os.getenv("RPC_URL")

    if not api_key or not rpc_url:
        raise ValueError("Missing required environment variables")

    # Initiate the BlockExplorer object
    block_explorer = BlockExplorer(api_key, "mainnet")
    address = "0xf165148978Fa3cE74d76043f833463c340CFB704"

    block_explorer.save_sourcecode(address, save_dir="sourcecode")


if __name__ == "__main__":
    main()


"""
sourcecode.keys()
dict_keys(['SourceCode', 'ABI', 'ContractName', 'CompilerVersion', 'CompilerType', 'OptimizationUsed', 'Runs', 'ConstructorArguments', 
'EVMVersion', 'Library', 'LicenseType', 'Proxy', 'Implementation', 'SwarmSource', 'SimilarMatch'])
"""
