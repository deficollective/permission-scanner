import os
import json
from dotenv import load_dotenv
from permission_scanner import ContractScanner, BlockExplorer

load_dotenv()


def load_config_from_file(file_path: str) -> dict:
    with open(file_path, "r") as file:
        return json.load(file)


def main():
    # load contracts from json
    config_json = load_config_from_file("example/contracts.json")
    contracts_addresses = config_json["Contracts"]
    project_name = config_json["Project_Name"]
    chain_name = config_json["Chain_Name"]

    # setup environment variables
    api_key = os.getenv("ETHERSCAN_API_KEY")
    rpc_url = os.getenv("RPC_URL")

    # initiate the BlockExplorer object
    # specify and it will find the right base_url based on src/permission_scanner/utils/block_explorer_config.json
    block_explorer = BlockExplorer(api_key, chain_name)

    # initiate the ContractScanner
    contract_scanner = ContractScanner(
        rpc_url,
        block_explorer,
        export_dir=f"results/{project_name}",
    )

    # Scan all contracts
    for contract in contracts_addresses:
        contract_scanner.scan_contract(contract)

    # Generate reports, save in result/{project_name}/reports
    contract_scanner.generate_reports(project_name)


if __name__ == "__main__":
    main()
