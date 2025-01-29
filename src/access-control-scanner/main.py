import argparse
import json
from enum import Enum
from web3 import Web3
from typing import Dict, List
import sys
import time
from tqdm import tqdm
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from get_rpc_url import get_rpc_url

# Event signatures
ROLE_GRANTED_EVENT = "RoleGranted(bytes32,address,address)"
ROLE_REVOKED_EVENT = "RoleRevoked(bytes32,address,address)"
ROLE_ADMIN_CHANGED_EVENT = "RoleAdminChanged(bytes32,bytes32,bytes32)"

class Action(Enum):
    GRANTED = "granted"
    REVOKED = "revoked"

def parse_args():
    parser = argparse.ArgumentParser(description='Access Control Scanner')
    parser.add_argument('--contract_address', required=True, help='Contract address to scan')
    parser.add_argument('--chain_name', required=True, help='Chain name')
    parser.add_argument('--starting_block', type=int, required=True, help='Starting block number')
    parser.add_argument('--end_block', type=int, help='End block number (defaults to current block)')
    return parser.parse_args()

def get_event_signatures(w3):
    return {
        'RoleGranted': w3.keccak(text=ROLE_GRANTED_EVENT).hex(),
        'RoleRevoked': w3.keccak(text=ROLE_REVOKED_EVENT).hex(),
        'RoleAdminChanged': w3.keccak(text=ROLE_ADMIN_CHANGED_EVENT).hex()
    }

def process_events(w3, contract_address: str, start_block: int, end_block: int, event_signatures: Dict[str, str]) -> Dict:
    temp: Dict[str, List[Dict]] = {}
    
    # Process blocks in chunks to avoid RPC throttling
    CHUNK_SIZE = 1000
    num_chunks = (end_block - start_block + CHUNK_SIZE) // CHUNK_SIZE
    
    print(f"\nScanning blocks {start_block} to {end_block}")
    print(f"Processing {num_chunks} chunks of {CHUNK_SIZE} blocks each")
    
    try:
        for block in tqdm(range(start_block, end_block + 1, CHUNK_SIZE), desc="Scanning blocks"):
            
            chunk_end = min(block + CHUNK_SIZE - 1, end_block)
            
            try:
                
                # Get logs for all events
                logs = w3.eth.get_logs({
                    'fromBlock': block,
                    'toBlock': chunk_end,
                    'address': contract_address
                })

                # in chunk found this many addresses
                print(f"Found {len(logs)} logs in chunk {block}-{chunk_end}")

                for log in logs:
                    
                    event_sig = log['topics'][0].hex()
                    
                    if event_sig in [event_signatures['RoleGranted'], event_signatures['RoleRevoked']]:
                        role = log['topics'][1].hex()
                        address = '0x' + log['topics'][2].hex()[-40:]  # Extract address from topic
                        
                        if role not in temp:
                            temp[role] = []
                        
                        temp[role].append({
                            'block': log['blockNumber'],
                            'address': address.lower(),
                            'action': Action.GRANTED.value if event_sig == event_signatures['RoleGranted'] else Action.REVOKED.value
                        })
            
            except Exception as e:
                print(f"\nError processing chunk {block}-{chunk_end}: {str(e)}")
                print("Retrying after a longer delay...")
                time.sleep(5)  # Longer delay on error
                continue
            
            # Add delay to avoid throttling
            time.sleep(1)
    
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
        print(f"\nStarting Access Control Scanner for contract: {args.contract_address}")
        print(f"Chain: {args.chain_name}")
        
        # Setup web3
        rpc_url = get_rpc_url(args.chain_name)
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        
        if not w3.is_connected():
            raise ConnectionError(f"Failed to connect to {args.chain_name}")
        
        print("Successfully connected to RPC endpoint")
        
        if not args.end_block:
            args.end_block = w3.eth.block_number

        # Get current block
        
        print(f"End block: {args.end_block}")
        
        # Get event signatures
        event_signatures = get_event_signatures(w3)
        
        # Process events
        temp = process_events(
            w3,
            args.contract_address,
            args.starting_block,
            args.end_block,
            event_signatures
        )
        
        print("\nComputing final state...")
        # Compute final state
        result = compute_final_state(temp)
        
        # Write results to files
        print("\nWriting results to files...")
        with open('temp_data.json', 'w') as f:
            json.dump(temp, f, indent=2)
        
        with open('final_state.json', 'w') as f:
            json.dump(result, f, indent=2)
        
        # Print results to command line
        print("\nCurrent Role Assignments:")
        print("------------------------")
        for role, addresses in result.items():
            print(f"\nRole: {role}")
            for addr in addresses:
                print(f"  - {addr}")
        
        print("\nProcess completed successfully!")
        print("Results have been saved to 'temp_data.json' and 'final_state.json'")

    except KeyboardInterrupt:
        print("\nProcess interrupted by user")
        sys.exit(1)
    
    except Exception as e:
        print(f"\nError: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()