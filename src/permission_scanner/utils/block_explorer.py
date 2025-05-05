import requests
from typing import Dict, Optional, Any
import json
from pathlib import Path
from .logger import setup_logger

logger = setup_logger(__name__, "logs/block_explorer.log")

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
        except KeyError:
            raise ValueError(
                f"Unsupported chain: {chain_name}. Supported chains are: {', '.join(block_explore_config.keys())}"
            )

        logger.info(f"Initialized BlockExplorer for chain: {chain_name}")

    def _make_request(
        self, module: str, action: str, address: str, chainid: Optional[int] = None
    ) -> Dict[str, Any]:
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
        if chainid:
            params["chainid"] = chainid

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

    def fetch_contract_metadata(self, address: str) -> Dict:
        """
        Fetch contract metadata from Etherscan,
        including contract name, proxy status, and implementation address.
        """
        chainid = block_explore_config[self.chain_name]["chainid"] or None
        result = self._make_request(
            module="contract", action="getsourcecode", address=address, chainid=chainid
        )
        contract_info = result[0]
        return {
            "ContractName": contract_info.get("ContractName"),
            "Proxy": contract_info.get("Proxy") == "1",
            "Implementation": contract_info.get("Implementation"),
        }
