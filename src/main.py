from slither.slither import Slither
from slither.core.declarations.function import Function
from slither.core.declarations.contract import Contract

from slither.tools.read_storage.read_storage import SlitherReadStorage, RpcInfo, get_storage_data

import json
from typing import  List
import urllib.error

from parse import init_args
from get_rpc_url import get_rpc_url
from get_etherscan_url import get_etherscan_url
from dotenv import load_dotenv

from markdown_generator import generate_full_markdown


def load_config_from_file(file_path: str) -> dict:
    with open(file_path, 'r') as file:
        return json.load(file)


# check for msg.sender checks
def get_msg_sender_checks(function: Function) -> List[str]:
    all_functions = (
        [f for f in function.all_internal_calls() if isinstance(f, Function)]
        + [m for f in function.all_internal_calls() if isinstance(f, Function) for m in f.modifiers]
        + [function]
        + [m for m in function.modifiers if isinstance(m, Function)]
        + [call for call in function.all_library_calls() if isinstance(call, Function)]
        + [m for call in function.all_library_calls() if isinstance(call, Function) for m in call.modifiers]
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


def get_permissions(contract: Contract, result: dict, all_state_variables_read: List[str], isProxy: bool, index: int):
    
    temp = {
        "Contract_Name": contract.name,
        "Functions": []
    }

    for function in contract.functions:
        # 1) list all modifiers in function
        # for output analysis
        modifiers = function.modifiers
        for call in function.all_internal_calls():
            if isinstance(call, Function):
                modifiers += call.modifiers
        for call in function.all_library_calls():
            if isinstance(call, Function):
                modifiers += call.modifiers

        listOfModifiers = sorted([m.name for m in set(modifiers)])

        
        # 2) detect conditions on msg.sender
        # in the full function scope
        msg_sender_condition = get_msg_sender_checks(function)

        if (len(modifiers) == 0 and len(msg_sender_condition) == 0):
            # no permission detected
            continue

        # list all state variables that are read
        # the variables available in storage will be read
        state_variables_read_inside_modifiers = [
            v.name
            for modifier in modifiers if modifier is not None
            for v in modifier.all_variables_read() if v is not None and v.name
        ]

        state_variables_read_inside_function = [
            v.name for v in function.all_state_variables_read() if v.name
        ]
        
        all_state_variables_read_this_func = []
        all_state_variables_read_this_func.extend(state_variables_read_inside_modifiers)
        all_state_variables_read_this_func.extend(state_variables_read_inside_function)
        all_state_variables_read_this_func = list(set(all_state_variables_read_this_func))

        all_state_variables_read.extend(all_state_variables_read_this_func)

        # 3) list all state variables that are written to inside this function
        state_variables_written = [
            v.name for v in function.all_state_variables_written() if v.name
        ]

        # 4) write everything to dict
        temp['Functions'].append({
            "Function": function.name,
            "Modifiers": listOfModifiers,
            "msg.sender_conditions": msg_sender_condition,
            "state_variables_read": all_state_variables_read_this_func,
            "state_variables_written": state_variables_written
        })
    
    # dump to result dict
    if isProxy and index == 0:
        result["proxy_permissions"] = temp
    elif isProxy and index == 1:
        result["permissions"] = temp
    else:
        # is normal contract
        result["permissions"] = temp

def main():
    load_dotenv()  # Load environment variables from .env file

    # load contracts from json
    config_json = load_config_from_file("contracts.json")
    
    contracts_addresses = config_json["Contracts"]
    project_name = config_json["Project_Name"]
    chain_name = config_json["Chain_Name"]
    
    rpc_url = get_rpc_url(chain_name)
    platform_key = get_etherscan_url()

    result = {}

    # instantiate slither rpc class
    rpc_info = RpcInfo(rpc_url, "latest")

    for contract_object in contracts_addresses:
        target_storage_vars = [] # target storage variables of this contract
        temp_global = {}

        # setup args for slither
        args = init_args(project_name, contract_object["address"], chain_name, rpc_url, platform_key, contract_object["name"])
        target = args.contract_source
        
        try:
            slither = Slither(target, **vars(args))
        except urllib.error.HTTPError as e:
            print(f"\033[33mFailed to compile contract at {contract_object} due to HTTP error: {e}\033[0m")
            continue  # Skip this contract and move to the next one
        except Exception as e:
            print(f"\033[33mAn error occurred while analyzing {contract_object}: {e}\033[0m")
            continue

        # retrieved contracts from the address (inherited and interacted contracts)
        contracts = slither.contracts

        # only take the one contract that is in the key
        # this filters out interacted contracts (we dont need the permissions of them)
        # does not exclude inherited contracts
        target_contract = [contract for contract in contracts if contract.name == contract_object["name"]]

        if len(target_contract) == 0:
            raise Exception(f"\033[31m\n \nThe contract name supplied in contract.json does not match any of the found contract names for this address: {contract_object}\033[0m")
        
        srs = SlitherReadStorage(target_contract, args.max_depth, rpc_info)
        srs.unstructured = False
        # Remove target prefix "mainnet:" e.g. mainnet:0x0 -> 0x0.
        address = target[target.find(":") + 1 :]
        srs.storage_address = address

        # step 1: check if inheriting a proxy pattern (go through all inherited contracts)
        # step 2: create slither object again, but with implementation address
        #    -> run analysis of storage layout and permissions of implementation address
        # step 3: read storage from proxy contract (location of storage) contract_address["address"]

        isProxy = False
        
        for inheritedContract in target_contract[0].inheritance:

            if inheritedContract.name in ["Proxy", "ERC1967Proxy", "ERC1967", "UUPS", "UpgradeableProxy"]:
                isProxy = True
                try:
                    contract_object["implementation_name"]
                except KeyError:
                    raise Exception(f'\033[31mProxy Contracts need a name for the implementation contract for contract {contract_object["address"]}. Please adhere to the template.\033[0m')
                IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
                raw_value = get_storage_data(srs.rpc_info.web3, srs.checksum_address, IMPLEMENTATION_SLOT, srs.rpc_info.block)
                # parse raw value and convert to address
                implementation_address = srs.convert_value_to_type(raw_value, 160, 0, "address")

                # scan the implementation address
                slither = Slither(f'{chain_name}:{implementation_address}', **vars(args))
                
                # get all the instantiated contracts (includes also interacted contracts) from the implementation contract
                implementation_contracts = slither.contracts_derived

                # find the instantiated/main implementation contract
                # user needs to supply the contract name of the instantiated contract in the contract object
                target_contract.extend([contract for contract in implementation_contracts if contract.name == contract_object["implementation_name"]])
                if len(target_contract) == 1:
                    raise Exception(f"\033[31m\n \nThe implementation name supplied in contract.json does not match any of the found implementation contract names for this address: {contract_object['address']}\033[0m")
                temp_global["Implementation_Address"] = implementation_address
                temp_global["Proxy_Address"] = contract_object["address"]
                break

            try:
                if contract_object["implementation_name"] == "GovernorBravoDelegate":
                    # get implementation address
                    IMPLEMENTATION_SLOT = 2
                    raw_value = get_storage_data(srs.rpc_info.web3, srs.checksum_address, IMPLEMENTATION_SLOT, srs.rpc_info.block)
                    # parse raw value and convert to address
                    implementation_address = srs.convert_value_to_type(raw_value, 160, 0, "address")

                    slither = Slither(f'{chain_name}:{implementation_address}', **vars(args))
                    implementation_contracts = slither.contracts_derived

                    # find the instantiated/main implementation contract
                    # user needs to supply the contract name of the instantiated contract in the contract object
                    target_contract.extend([contract for contract in implementation_contracts if contract.name == contract_object["implementation_name"]])
                    if len(target_contract) == 1:
                        raise Exception(f"\033[31m\n \nThe implementation name supplied in contract.json does not match any of the found implementation contract names for this address: {contract_object['address']}\033[0m")
                    temp_global["Implementation_Address"] = implementation_address
                    temp_global["Proxy_Address"] = contract_object["address"]
            except KeyError:
                # not a Governor Bravo type contract
                pass

        if not isProxy:
            temp_global["Address"] = contract_object["address"]

        # end setup
        ##################################################
        ##################################################
        ##################################################

        ##################################################
        ##################################################
        ##################################################
        # start analysis


        # start analysis of main contract (can be proxy, then also the implementation contract is analysed)
        for i, contract in enumerate(target_contract):
            # get permissions and store inside target_storage_vars
            get_permissions(contract, temp_global, target_storage_vars, isProxy, i)

        target_storage_vars = list(set(target_storage_vars)) # remove duplicates

        # Three steps to retrieve storage variables with slither
        # 1. set target variables
        # 2. compute storage keys
        # 3. retrieve slots from the keys

        # sets target variables
        # adapted logic, extracted from method `get_all_storage_variables` of SlitherReadStorage class
        for contract in srs._contracts:
            for var in contract.state_variables_ordered:
                if var.name in target_storage_vars:
                    # achieve step 1.
                    srs._target_variables.append((contract, var))
                
                # add all constant and immutable variable to a list to do the required look-up
                if not var.is_stored:
                    
                    # functionData is a dict
                    for functionData in temp_global["permissions"]["Functions"]:
                        # check if e.g storage variable owner is part of this function 
                        if var.name in functionData["state_variables_read"]:
                            # check if already added some constants/immutables

                            # Ensure key exists
                            if "immutables_and_constants" not in functionData:
                                functionData["immutables_and_constants"] = []
                            
                            # Check if the variable has an expression and is not the proxy marker
                            if var.expression and str(var.expression) != "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc":
                                try:
                                    raw_value = get_storage_data(
                                        srs.rpc_info.web3, contract_object["address"], 
                                        str(var.expression), srs.rpc_info.block
                                    )
                                    value = srs.convert_value_to_type(raw_value, 160, 0, "address")
                                    functionData["immutables_and_constants"].append(
                                        {"name": var.name, "slot": str(var.expression), "value": value}
                                    )
                                except Exception:
                                    functionData["immutables_and_constants"].append(
                                        {"name": var.name, "slot": str(var.expression)}
                                    )
                            else:
                                functionData["immutables_and_constants"].append({"name": var.name})

        # step 2. computes storage keys for target variables 
        srs.get_target_variables()

        # step 3. get the values of the target variables and their slots
        try:
            srs.walk_slot_info(srs.get_slot_values)
        except urllib.error.HTTPError as e:
            print(f"\033[33mFailed to fetch storage from contract at {contract_object} due to HTTP error: {e}\033[0m")
            continue  # Skip this contract and move to the next one
        except Exception as e:
            print(f"\033[33mAn error occurred while fetching storage slots from contract {contract_object}: {e}\033[0m")
            continue
        
        storageValues = {}
        # merge storage retrieval with contracts
        for key, value in srs.slot_info.items():
            contractDict = temp_global["permissions"]
            storageValues[value.name] = value.value
            # contractDict["Functions"] is a list, functionData a dict
            for functionData in contractDict["Functions"]:
                # check if e.g storage variable owner is part of this function 
                if value.name in functionData["state_variables_read"]:
                    # if so, add a key value pair to the functionData object, to improve readability of report
                    functionData[value.name] = value.value

        if len(storageValues.values()):
            contractDict["storage_values"] = storageValues

        try:
            if contract_object["implementation_name"]:
                result[contract_object["implementation_name"]] = temp_global
        except Exception:
            result[contract_object["name"]] = temp_global

    with open("permissions.json","w") as file:
        json.dump(result, file, indent=4)

    content = generate_full_markdown("", contracts_addresses, result)

    with open("markdown.md", "w") as file:
        file.write(content)


main()
