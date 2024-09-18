import os

def get_rpc_url(network: str) -> str:
    rpc_urls = {
        "mainet": os.getenv("MAINNETRPC"),
        # Add more networks as needed
    }

    return rpc_urls.get(network, "https://default.network.url")  # default value if no match


