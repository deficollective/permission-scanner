import os

def get_platform_key() -> str:
    return os.getenv("ETHERSCAN_API_KEY")

