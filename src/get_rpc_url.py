import os

def get_rpc_url(network: str) -> str:
    rpc_urls = {
        "mainet": os.getenv("MAINNET_RPC"),
        "optim": os.getenv("OPTIMISTIC_RPC"),
        "base": os.getenv("BASE_RPC"),
        # Add more networks as needed
    }

    return rpc_urls.get(network, "https://default.network.url")  # default value if no match


