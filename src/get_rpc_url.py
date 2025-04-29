import os

def get_rpc_url(network: str) -> str:
    rpc_urls = {
        "mainnet": os.getenv("MAINNET_RPC"),
        "bsc": os.getenv("BSC_RPC"),
        "poly": os.getenv("POLYGON_RPC"),
        "polyzk": os.getenv("POLYGON_ZK_RPC"),
        "base": os.getenv("BASE_RPC"),
        "arbi": os.getenv("ARBITRUM_RPC"),
        "nova.arbi": os.getenv("NOVA_ARBITRUM_RPC"),
        "linea": os.getenv("LINEA_RPC"),
        "ftm": os.getenv("FANTOM_RPC"),
        "blast": os.getenv("BLAST_RPC"),
        "optim": os.getenv("OPTIMISTIC_RPC"),
        "avax": os.getenv("AVAX_RPC"),
        "bttc": os.getenv("BTTC_RPC"),
        "celo": os.getenv("CELO_RPC"),
        "cronos": os.getenv("CRONOS_RPC"),
        "frax": os.getenv("FRAX_RPC"),
        "gno": os.getenv("GNOSIS_RPC"),
        "kroma": os.getenv("KROMA_RPC"),
        "mantle": os.getenv("MANTLE_RPC"),
        "moonbeam": os.getenv("MOONBEAM_RPC"),
        "moonriver": os.getenv("MOONRIVER_RPC"),
        "opbnb": os.getenv("OPBNB_RPC"),
        "scroll": os.getenv("SCROLL_RPC"),
        "taiko": os.getenv("TAIKO_RPC"),
        "wemix": os.getenv("WEMIX_RPC"),
        "era.zksync": os.getenv("ZKSYNC_ERA_RPC"),
        "xai": os.getenv("XAI_RPC"),
    }
    
    rpc_url = rpc_urls.get(network)
    
    if rpc_url is None:
        raise KeyError(f"Network '{network}' not found in pre-configured chains. Please set your network in get_rpc_url.py")

    return rpc_url


def get_chain_id(network: str) -> int:
    chain_ids = {
        "mainnet": 1,
        "bsc": 56,
        "poly": 137,
        "polyzk": 1101,
        "base": 8453,
        "arbi": 42161,
        "nova.arbi": 42170,
        "linea": 59144,
        "ftm": 250,
        "blast": 81457,
        "optim": 10,
        "avax": 43114,
        "bttc": 199,
        "celo": 42220,
        "cronos": 25,
        "frax": 252,
        "gno": 100,
        "kroma": 255,
        "mantle": 5000,
        "moonbeam": 1284,
        "moonriver": 1285,
        "opbnb": 204,
        "scroll": 534352,
        "taiko": 167000,
        "wemix": 1111,
        "era.zksync": 324,
        "xai": 660279,
    }

    if network not in chain_ids:
        raise ValueError(f"Unknown network name: {network}")

    return chain_ids[network]
