import os

def get_platform_key(network: str) -> str:
    rpc_urls = {
        "mainet": os.getenv("ETHERSCAN_API_KEY"),
        # Add more networks as needed
    }

    return rpc_urls.get(network, "123")  # default value if no match
