import os

def get_etherscan_url() -> str:
    etherscan_url = os.getenv("ETHERSCAN_API_KEY")
    
    if etherscan_url is None:
        raise KeyError("Please set a etherscan api key in your .env")

    return etherscan_url

