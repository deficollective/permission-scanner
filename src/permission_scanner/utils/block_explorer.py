import requests
from typing import Dict, Optional, Any
import json
from pathlib import Path
import os
from json import JSONDecodeError


# Read the config file from the same directory as this script
with open(Path(__file__).parent / "block_explorer_config.json", "r") as f:
    block_explore_config = json.load(f)


class BlockExplorer:
    """Service for interacting with Etherscan API."""

    def __init__(self, api_key: str, chain_name: str):
        if not api_key:
            raise ValueError("API key is required")
        self.api_key = api_key
        self.chain_name = chain_name
        try:
            self.base_url = block_explore_config[chain_name]["base_url"]
            self.chainid = block_explore_config[chain_name].get("chainid", None)
        except KeyError:
            raise ValueError(
                f"Unsupported chain: {chain_name}. Supported chains are: {', '.join(block_explore_config.keys())}"
            )
        self.sourcecode = {}

    def _make_request(self, module: str, action: str, address: str) -> Dict[str, Any]:
        """
        Make a request to the BeraScan API.

        Args:
            module (str): The API module to call.
            action (str): The action to perform.
            address (str): The contract address.
            chain_id (int, optional): The chain ID, etherscan has v2 api that supports 50+ chains
        Returns:
            dict: The API response data.

        Raises:
            requests.exceptions.RequestException: If the API request fails.
            ValueError: If the response indicates an error.
        """
        params = {
            "module": module,
            "action": action,
            "address": address,
            "apikey": self.api_key,
        }
        if self.chainid:
            params["chainid"] = self.chainid

        try:
            with requests.get(self.base_url, params=params) as response:
                if response.status_code != 200:
                    raise ValueError(f"API Error: {response.text}")
                data = response.json()
        except Exception as e:
            raise RuntimeError(f"Request failed: {e}")

        if data["status"] != "1":
            raise ValueError(f"API Error: {data.get('message', 'Unknown error')}")

        return data["result"]

    def fetch_source_code(self, address: str) -> Dict[str, Any]:
        """
        Fetch the source code for a verified contract.

        Args:
            contract_address (str): The address of the contract to fetch source code for.

        Returns:
            Dict[str, Any]: The contract source code information including:
                - SourceCode: The actual source code
                - ABI: The contract ABI
                - ContractName: The name of the contract
                - CompilerVersion: The compiler version used
                - OptimizationUsed: Whether optimization was used
                - Runs: Number of optimization runs
                - ConstructorArguments: Constructor arguments
                - Library: Library information
                - LicenseType: The license type
                - Proxy: Whether the contract is a proxy
                - Implementation: Implementation address if proxy
                - SwarmSource: Swarm source if available
        """
        sourcecode = self.sourcecode.get(address, None)
        if sourcecode is None:
            result = self._make_request(
                module="contract",
                action="getsourcecode",
                address=address,
            )
            if isinstance(result, list) and len(result) > 0:
                self.sourcecode[address] = result[0]
            else:
                raise ValueError(f"No source code found for contract {address}")

    def get_contract_metadata(self, address: str) -> Dict:
        """
        Fetch contract metadata from Etherscan,
        including contract name, proxy status, and implementation address.
        """
        self.fetch_source_code(address)
        all_data = self.sourcecode.get(address)
        if all_data is None:
            raise ValueError(f"No source code found for contract {address}")
        metadata = {
            "ContractName": all_data.get("ContractName"),
            "Proxy": all_data.get("Proxy") == "1",
            "Implementation": all_data.get("Implementation"),
            # "CompilerVersion": all_data.get("CompilerVersion"),
            # "Library": all_data.get("Library"),
        }
        return metadata

    def save_sourcecode(self, address: str, save_dir: str) -> str:
        """
        Fetch contract source code from Berascan and save it locally.

        Args:
            address (str): The contract address
            save_dir (str): Directory to save the source code

        Returns:
            str: Path to the saved source code file
        """
        self.fetch_source_code(address)
        source_code = self.sourcecode[address]["SourceCode"]
        contract_name = self.sourcecode[address]["ContractName"]

        # Create export directory
        export_dir = os.path.join(save_dir, f"{address}-{contract_name}")
        if not os.path.exists(export_dir):
            os.makedirs(export_dir)

        # Handle different source code formats
        dict_source_code = None
        try:
            # Try to parse as double-braced JSON
            dict_source_code = json.loads(source_code[1:-1])
            assert isinstance(dict_source_code, dict)
        except (JSONDecodeError, AssertionError):
            try:
                # Try to parse as single-braced JSON
                dict_source_code = json.loads(source_code)
                assert isinstance(dict_source_code, dict)
            except (JSONDecodeError, AssertionError):
                # Handle as single file
                filename = os.path.join(export_dir, f"{contract_name}.sol")
                with open(filename, "w", encoding="utf8") as f:
                    f.write(source_code)
                return filename

        # Handle multiple files case
        if "sources" in dict_source_code:
            source_codes = dict_source_code["sources"]
        else:
            source_codes = dict_source_code

        filtered_paths = []
        for filename, source_code in source_codes.items():
            path_filename = Path(filename)

            # Only keep solidity files
            if path_filename.suffix not in [".sol", ".vy"]:
                continue

            # Handle contracts directory imports
            if "contracts" == path_filename.parts[0] and not filename.startswith("@"):
                path_filename = Path(
                    *path_filename.parts[path_filename.parts.index("contracts") :]
                )

            # Convert absolute paths to relative
            if path_filename.is_absolute():
                path_filename = Path(*path_filename.parts[1:])

            filtered_paths.append(path_filename.as_posix())
            path_filename_disk = Path(export_dir, path_filename)

            # Ensure path is within allowed directory
            allowed_path = os.path.abspath(export_dir)
            if (
                os.path.commonpath((allowed_path, os.path.abspath(path_filename_disk)))
                != allowed_path
            ):
                raise IOError(
                    f"Path '{path_filename_disk}' is outside of the allowed directory: {allowed_path}"
                )

            # Create directory if needed
            os.makedirs(path_filename_disk.parent, exist_ok=True)

            # Write file
            with open(path_filename_disk, "w", encoding="utf8") as f:
                f.write(source_code["content"])

        # Handle remappings
        remappings = dict_source_code.get("settings", {}).get("remappings", [])
        if remappings:
            remappings_path = os.path.join(export_dir, "remappings.txt")
            with open(remappings_path, "w", encoding="utf8") as f:
                for remapping in remappings:
                    if "=" in remapping:
                        origin, dest = remapping.split("=", 1)
                        # Always use a trailing slash for the destination
                        f.write(f"{origin}={str(Path(dest) / '_')[:-1]}\n")

        # Create metadata config
        metadata_config = {
            "solc_remaps": remappings if remappings else {},
            "solc_solcs_select": self.sourcecode[address].get("CompilerVersion", ""),
            "solc_args": " ".join(
                filter(
                    None,
                    [
                        (
                            "--via-ir"
                            if dict_source_code.get("settings", {}).get("viaIR")
                            else ""
                        ),
                        (
                            f"--optimize --optimize-runs {self.sourcecode[address].get('Runs', '')}"
                            if self.sourcecode[address].get("OptimizationUsed") == "1"
                            else ""
                        ),
                        (
                            f"--evm-version {self.sourcecode[address].get('EVMVersion')}"
                            if self.sourcecode[address].get("EVMVersion")
                            and self.sourcecode[address].get("EVMVersion") != "Default"
                            else ""
                        ),
                    ],
                )
            ),
        }

        with open(
            os.path.join(export_dir, "crytic_compile.config.json"), "w", encoding="utf8"
        ) as f:
            json.dump(metadata_config, f)

        # Find main contract file
        main_contract_path = None
        for path in filtered_paths:
            path_filename = Path(path)
            if path_filename.stem == contract_name:
                main_contract_path = os.path.join(export_dir, path)
                break
            elif path_filename.stem.lower() == contract_name.lower():
                main_contract_path = os.path.join(export_dir, path)
                break

        # If no main contract found, use first .sol file
        if main_contract_path is None:
            for root, _, files in os.walk(export_dir):
                for file in files:
                    if file.endswith(".sol"):
                        main_contract_path = os.path.join(root, file)
                        break
                if main_contract_path:
                    break

        return main_contract_path
