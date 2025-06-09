import json
import requests


# def main():
#     todo: retrieve storage value from slot 4 and 5 of the address of a MCMS that should be scanned
#     quorum = "0x0000000000000000000000000000000000020202020101010101010101010303"[2:]
#     parents = "0x00000000000000000000000000000000000b0b0b000001010101010101010000"[2:]
#     reversedQuorum = quorum[::-1]
#     reversedParents = parents[::-1]
#     res = {}
#     groupedByParent = {}


#     for i in range(0, 64, 2):
#         index = i//2
#         quorum = f"{reversedQuorum[i+1]}{reversedQuorum[i]}"
#         parent = f"{reversedParents[i+1]}{reversedParents[i]}"
#         res[index] = {
#             "index": index,
#             "quorum": quorum,
#             "parent": parent
#         }
#         if quorum == '00' and parent == '00':
#             continue

#         try:
#             if len(groupedByParent[parent]) == 0:
#                 groupedByParent[parent] = [index]
#             else:
#                 groupedByParent[parent].append(index)
#         except Exception:
#             groupedByParent[parent] = [index]

#     with open("ccip.json","w") as file:
#         json.dump(res, file, indent=4)
    
#     # group grouped by parent
#     # means node grouped by parent
#     # filtered out disabled groups/nodes
#     with open("groupGroupedByParent.json","w") as file:
#         json.dump(groupedByParent, file, indent=4)


def increment_hex_slot(hex_slot: str, increment: int = 1) -> str:
    # Remove 0x prefix and convert to int
    int_slot = int(hex_slot, 16)
    
    # Increment
    int_slot += increment
    
    # Convert back to hex, pad to 64 chars (32 bytes), and prefix with 0x
    return "0x" + format(int_slot, '064x')


def main():

    res = {}
    groupedByGroup = {}

    # RPC endpoint (e.g. Infura, Alchemy, or local node)
    rpc_url = "https://arbitrum-mainnet.infura.io/v3/95aa7b234c9e47b593be00f08cca4c32"

    # Define parameters
    contract_address = "0xf4c257b5c6c526d56367a602e87b1932d13e67cb"
    slot_index = "0xc2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b"  # this is the storage slot number where signers start
    lengthOfArray = 48

    for el in range(lengthOfArray):
        payload = {
            "jsonrpc": "2.0",
            "method": "eth_getStorageAt",
            "params": [contract_address, slot_index, "latest"],
            "id": 1
        }

        response = requests.post(rpc_url, json=payload)
        data = response.json()

        # storage value
        # storageValue = "0x00000000000000000000080006e5891d9b2ee77740355a309baf49caab672f98"[2:]
        storageValue = data["result"][2:]

        # split the slot into its components
        arrayData = storageValue[:24]
        address = storageValue[24:]
        print(f"index: {arrayData[-2:]}") # index
        print(f"group: {arrayData[-4:-2]}") # group
        print(f"address: 0x{address}")

        res[el] = {
            "index": arrayData[-2:],
            "group": arrayData[-4:-2],
            "address": f"0x{address}"
        }
        try:
            if len(groupedByGroup[arrayData[-4:-2]]) == 0:
                groupedByGroup[arrayData[-4:-2]] = [f"0x{address}"]
            else:
                groupedByGroup[arrayData[-4:-2]].append(f"0x{address}")
        except Exception:
            groupedByGroup[arrayData[-4:-2]] = [f"0x{address}"]

        # overwrite slot_index
        slot_index = increment_hex_slot(slot_index, 1)

    with open("signersArray.json","w") as file:
        json.dump(res, file, indent=4)
    with open("signersPerNode.json","w") as file:
        json.dump(groupedByGroup, file, indent=4)



main()