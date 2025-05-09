import os
import json
import logging
from dotenv import load_dotenv
from permission_scanner import ContractScanner, BlockExplorer
from permission_scanner.utils.markdown_generator import generate_full_markdown


def load_config_from_file(file_path: str) -> dict:
    """Load configuration from a JSON file.

    Args:
        file_path (str): Path to the configuration file

    Returns:
        dict: Configuration data

    Raises:
        FileNotFoundError: If the config file doesn't exist
        json.JSONDecodeError: If the config file is not valid JSON
    """
    try:
        with open(file_path, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        raise
    except json.JSONDecodeError as e:
        raise


def main():
    """Main function to run the contract scanner."""
    try:
        # Load environment variables
        load_dotenv()

        # Load contracts from json
        config_json = load_config_from_file("example/contracts.json")
        contracts_addresses = config_json["Contracts"]
        project_name = config_json["Project_Name"]
        chain_name = config_json["Chain_Name"]

        # Setup environment variables
        api_key = os.getenv("ETHERSCAN_API_KEY")
        rpc_url = os.getenv("RPC_URL")

        if not api_key or not rpc_url:
            raise ValueError("Missing required environment variables")

        # Initiate the BlockExplorer object
        block_explorer = BlockExplorer(api_key, chain_name)

        # Initialize scanner
        export_dir = f"results/{project_name}"

        # Scan each contract
        all_scan_results = {}
        all_contract_data_for_markdown = []

        for address in contracts_addresses:
            # initiate scanner for each address
            scanner = ContractScanner(
                block_explorer=block_explorer,
                rpc_url=rpc_url,
                export_dir=export_dir,
                address=address,
            )
            final_result, contract_data_for_markdown = scanner.scan()
            all_scan_results.update(final_result)
            all_contract_data_for_markdown += contract_data_for_markdown

        json_path = os.path.join(export_dir, "permissions.json")
        with open(json_path, "w") as f:
            json.dump(all_scan_results, f, indent=4)

        markdown_path = os.path.join(export_dir, "markdown.md")
        markdown_content = generate_full_markdown(
            project_name, all_contract_data_for_markdown, all_scan_results
        )
        with open(markdown_path, "w") as f:
            f.write(markdown_content)
    except Exception as e:
        raise


if __name__ == "__main__":
    main()
