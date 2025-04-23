import argparse
import json
from enum import Enum
from typing import Dict, List
import sys
import time
import os
import requests
from web3 import Web3
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from get_platform_key import get_platform_key


# Event signatures
ROLE_GRANTED_EVENT = "RoleGranted(bytes32,address,address)"
ROLE_REVOKED_EVENT = "RoleRevoked(bytes32,address,address)"
ROLE_ADMIN_CHANGED_EVENT = "RoleAdminChanged(bytes32,bytes32,bytes32)"

# Hash the event signatures
w3 = Web3()
EVENT_SIGNATURES = {
    'RoleGranted': w3.keccak(text=ROLE_GRANTED_EVENT).hex(),
    'RoleRevoked': w3.keccak(text=ROLE_REVOKED_EVENT).hex(),
    'RoleAdminChanged': w3.keccak(text=ROLE_ADMIN_CHANGED_EVENT).hex()
}

class Action(Enum):
    GRANTED = "granted"
    REVOKED = "revoked"

def parse_args():
    parser = argparse.ArgumentParser(description='Access Control Scanner (Etherscan API)')
    parser.add_argument('--contract_address', required=True, help='Contract address to scan')
    parser.add_argument('--chain_id', required=True, help='Chain id (look up on chainlist.org)')
    parser.add_argument('--starting_block', type=int, required=True, help='Starting block number')
    parser.add_argument('--end_block', type=int, help='End block number (defaults to current block)')
    return parser.parse_args()

def get_etherscan_url() -> str:
    return "https://api.etherscan.io/v2/api"

def process_events(api_url: str, api_key: str, contract_address: str, chain_id: int, start_block: int, end_block: int) -> Dict:
    temp: Dict[str, List[Dict]] = {}
    page = 1
    offset = 1000  # Number of records per page
    
    print(f"\nScanning blocks {start_block} to {end_block}")
    print("Using Etherscan API for data retrieval")
    
    try:
        while True:
            try:
                params = {
                    'chainid': chain_id,
                    'module': 'logs',
                    'action': 'getLogs',
                    'address': contract_address,
                    'fromBlock': start_block,
                    'toBlock': end_block,
                    'page': page,
                    'offset': offset,
                    'apikey': api_key
                }

                print(api_key)
                
                response = requests.get(api_url, params=params)
                data = response.json()
                
                if data['status'] != '1':
                    print(f"\nError from Etherscan API: {data.get('message', 'Unknown error')}")
                    break
                
                logs = data['result']
                if not logs:
                    break
                
                print(f"\nProcessing page {page} - Found {len(logs)} logs")
                
                for log in logs:
                    topics = log['topics']
                    event_sig = topics[0]
                    
                    if len(topics) >= 3:  # Make sure we have enough topics
                        # Check if this is a role event we're interested in
                        if event_sig in [EVENT_SIGNATURES['RoleGranted'], EVENT_SIGNATURES['RoleRevoked']]:
                            role = topics[1]
                            address = '0x' + topics[2][-40:]  # Extract address from topic
                            
                            if role not in temp:
                                temp[role] = []
                            
                            temp[role].append({
                                'block': int(log['blockNumber'], 16),  # Convert hex to int
                                'address': address.lower(),
                                'action': Action.GRANTED.value if event_sig == EVENT_SIGNATURES['RoleGranted'] else Action.REVOKED.value
                            })
                
                page += 1
                # Add delay to avoid rate limiting
                time.sleep(0.2)
            
            except requests.exceptions.RequestException as e:
                print(f"\nError making request to Etherscan API: {str(e)}")
                print("Retrying after a longer delay...")
                time.sleep(5)
                continue
            
    except KeyboardInterrupt:
        print("\nProcess interrupted by user. Saving partial results...")
        return temp
    
    except Exception as e:
        print(f"\nFatal error during event processing: {str(e)}")
        raise
    
    return temp

def compute_final_state(temp: Dict) -> Dict:
    try:
        result: Dict[str, List[str]] = {}
        
        for role, events in temp.items():
            # Sort events by block number
            sorted_events = sorted(events, key=lambda x: x['block'])
            
            # Initialize role in result if not exists
            if role not in result:
                result[role] = []
            
            # Process events in chronological order
            for event in sorted_events:
                if event['action'] == Action.GRANTED.value:
                    if event['address'] not in result[role]:
                        result[role].append(event['address'])
                elif event['action'] == Action.REVOKED.value:
                    if event['address'] in result[role]:
                        result[role].remove(event['address'])
        
        return result
    
    except Exception as e:
        print(f"\nError computing final state: {str(e)}")
        print("Printing temp data...")
        print("--------------------")
        print(json.dumps(temp, indent=2))
        raise

def main():
    try:
        args = parse_args()
        print(f"\nStarting Access Control Scanner (Etherscan API) for contract: {args.contract_address}")
        print(f"Chain: {args.chain_id}")
        
        # Get API URL and key
        api_url = get_etherscan_url()
        api_key = get_platform_key()
        
        if not api_key:
            raise ValueError(f"No API key found for chain {args.chain_name}")
        
        # Process events
        temp = process_events(
            api_url,
            api_key,
            args.contract_address,
            args.chain_id,
            args.starting_block,
            args.end_block
        )
        
        print("\nComputing final state...")
        # Compute final state
        result = compute_final_state(temp)
        
        # Write results to files
        print("\nWriting results to files...")
        with open('temp_data_etherscan.json', 'w') as f:
            json.dump(temp, f, indent=2)
        
        with open('final_state_etherscan.json', 'w') as f:
            json.dump(result, f, indent=2)
        
        # Print results to command line
        print("\nCurrent Role Assignments:")
        print("------------------------")
        for role, addresses in result.items():
            print(f"\nRole: {role}")
            for addr in addresses:
                print(f"  - {addr}")
        
        print("\nProcess completed successfully!")
        print("Results have been saved to 'temp_data_etherscan.json' and 'final_state_etherscan.json'")

    except KeyboardInterrupt:
        print("\nProcess interrupted by user")
        sys.exit(1)
    
    except Exception as e:
        print(f"\nError: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
