import os

import urllib.request
import urllib.parse
import json

def get_etherscan_url() -> str:
    etherscan_url = os.getenv("ETHERSCAN_API_KEY")
    
    if etherscan_url is None:
        raise KeyError("Please set a etherscan api key in your .env")

    return etherscan_url


def fetch_contract_metadata(address, apikey, chainid=1):
    base_url = "https://api.etherscan.io/v2/api"
    params = {
        "chainid": chainid,
        "module": "contract",
        "action": "getsourcecode",
        "address": address,
        "apikey": apikey
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        with urllib.request.urlopen(url) as response:
            if response.status != 200:
                raise Exception(f"HTTP error {response.status}")
            data = json.load(response)
    except Exception as e:
        raise RuntimeError(f"Request failed: {e}")
    
    if data.get("status") != "1":
        raise ValueError(f"API error: {data.get('message', 'Unknown error')}")

    result = data.get("result", [])
    if not result:
        raise ValueError("No contract data found")

    contract_info = result[0]
    return {
        "ContractName": contract_info.get("ContractName"),
        "Proxy": contract_info.get("Proxy") == "1",
        "Implementation": contract_info.get("Implementation")
    }
