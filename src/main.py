from slither.slither import Slither
from slither.core.declarations.function import Function
from slither.core.declarations.contract import Contract

from slither.tools.read_storage.read_storage import SlitherReadStorage, RpcInfo
from slither.exceptions import SlitherError


import json
from typing import  List

from parse import parse_args



# check for msg.sender checks
def get_msg_sender_checks(function: Function) -> List[str]:
    all_functions = (
        [f for f in function.all_internal_calls() if isinstance(f, Function)]
        + [function]
        + [m for m in function.modifiers if isinstance(m, Function)]
    )

    all_nodes_ = [f.nodes for f in all_functions]
    all_nodes = [item for sublist in all_nodes_ for item in sublist]

    all_conditional_nodes = [
        n for n in all_nodes if n.contains_if() or n.contains_require_or_assert()
    ]
    all_conditional_nodes_on_msg_sender = [
        str(n.expression)
        for n in all_conditional_nodes
        if "msg.sender" in [v.name for v in n.solidity_variables_read]
    ]
    return all_conditional_nodes_on_msg_sender




def get_permissions(contract: Contract, result: dict, all_state_variables_read: List[str]):
    
    temp = {
        "Contract_Name": contract.name,
        "Functions": []
    }

    for function in contract.functions:
        # 1) list all modifiers in function
        modifiers = function.modifiers
        for call in function.all_internal_calls():
            if isinstance(call, Function):
                modifiers += call.modifiers
        for (_, call) in function.all_library_calls():
            if isinstance(call, Function):
                modifiers += call.modifiers
        listOfModifiers = sorted([m.name for m in set(modifiers)])
        
        # 2) detect conditions on msg.sender
        msg_sender_condition = get_msg_sender_checks(function)

        if (len(modifiers) == 0 and len(msg_sender_condition) == 0):
            # no permission detected
            continue
        
        # TODO: retrieve variables from msg.sender condition 

        # TODO: remove
        # list all state variables that are read
        state_variables_read = [v.name for modifier in modifiers for v in modifier.all_variables_read() if v.name]
        all_state_variables_read.extend(state_variables_read)

        # 3) list all state variables that are written to inside this function
        state_variables_written = [
            v.name for v in function.all_state_variables_written() if v.name
        ]

        # 4) write everything to dict
        temp['Functions'].append({
            "Function": function.name,
            "Modifiers": listOfModifiers,
            "msg.sender_conditions": msg_sender_condition,
            "state_variables_read": state_variables_read,
            "state_variables_written": state_variables_written
        })
    
    # dump to result dict
    result[contract.name] = temp

# TODO: assume the python script is called in a loop, with 1 address at the time
def main():
    all_state_variables_read = []
    
    result = {}

    args = parse_args()

    if len(args.contract_source) == 2:
        # Source code is file.sol or project directory
        source_code, target = args.contract_source
        slither = Slither(source_code, **vars(args))
    else:
        # Source code is published and retrieved via etherscan
        target = args.contract_source[0]
        slither = Slither(target, **vars(args))

    if args.contract_name:
        contracts = slither.get_contract_from_name(args.contract_name)
        if len(contracts) == 0:
            raise SlitherError(f"Contract {args.contract_name} not found.")
    else:
        contracts = slither.contracts

    
    rpc_info = RpcInfo(args.rpc_url, "latest")

    srs = SlitherReadStorage(contracts, args.max_depth, rpc_info)
    srs.unstructured = bool(args.unstructured)
    # Remove target prefix e.g. rinkeby:0x0 -> 0x0.
    address = target[target.find(":") + 1 :]
    # Default to implementation address unless a storage address is given.
    if not args.storage_address:
        args.storage_address = address
    srs.storage_address = args.storage_address

    for contract in contracts:
        get_permissions(contract, result, all_state_variables_read)

    # sets target variables
    srs.get_all_storage_variables(lambda x: bool(x.name in all_state_variables_read))
    #srs.get_all_storage_variables() # unfiltered
    
    # computes storage keys for target variables 
    srs.get_target_variables() # can out leave out args?? I think so (optional fields)

    # get the values of the target variables and their slots
    srs.walk_slot_info(srs.get_slot_values)


    # merge storage retrieval with contracts
    for key, value in srs.slot_info.items():
        contractName = key.split(".")[0] # assume key like "TroveManager._owner"
        contractDict = result[contractName]
        contractDict[value.name] = value.value
        
    
    with open("values.json", "w", encoding="utf-8") as file:
        slot_infos_json = srs.to_json()
        json.dump(slot_infos_json, file, indent=4)

    with open("data.json","w") as file:
        json.dump(result, file, indent=4)



main()