import os
import json
import logging
from dotenv import load_dotenv
from permission_scanner import ContractScanner
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
        config_json = load_config_from_file("example/contracts_full.json")
        contracts_addresses = config_json["Contracts"]
        project_name = config_json["Project_Name"]
        chain_name = config_json["Chain_Name"]

        # Setup environment variables
        block_explorer_api_key = os.getenv("ETHERSCAN_API_KEY")
        rpc_url = os.getenv("RPC_URL")

        if not block_explorer_api_key or not rpc_url:
            raise ValueError("Missing required environment variables")

        export_dir = f"results"

        # Scan each contract
        all_scan_results = {}
        all_contract_data_for_markdown = []

        for address in contracts_addresses:
            # initiate scanner for each address
            scanner = ContractScanner(
                project_name=project_name,
                address=address,
                chain_name=chain_name,
                block_explorer_api_key=block_explorer_api_key,
                rpc_url=rpc_url,
                export_dir=export_dir,
            )
            final_result, contract_data_for_markdown = scanner.scan()
            all_scan_results.update(final_result)
            all_contract_data_for_markdown += contract_data_for_markdown

        report_dir = f"{export_dir}/{project_name}-reports"
        os.makedirs(report_dir, exist_ok=True)
        json_path = os.path.join(report_dir, "permissions.json")
        markdown_path = os.path.join(report_dir, "markdown.md")

        with open(json_path, "w") as f:
            json.dump(all_scan_results, f, indent=4)
        markdown_content = generate_full_markdown(
            project_name, all_contract_data_for_markdown, all_scan_results
        )
        with open(markdown_path, "w") as f:
            f.write(markdown_content)
    except Exception as e:
        raise


if __name__ == "__main__":
    main()
