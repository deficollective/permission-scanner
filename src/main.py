from slither.slither import Slither
from slither.core.declarations.function import Function

from crytic_compile import compile_all

import json
from typing import List

# args = "TODO"
target = "contracts/Liquity/TroveManager.sol"

ast = "--ast-compact-json"
# if args.legacy_ast:
#     ast = "--ast-json"

compilations = compile_all(target) # leave out additional args
slither_instances = []

for compilation in compilations:
    slither = Slither(compilation, ast_format=ast) # **vars(args)
    slither_instances.append(slither)

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


result = {}


for slither in slither_instances:
    for contract in slither.contracts_derived:
        result['Contract'] = {'Name': contract.name, 'Functions': []}
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
            # 3) list all state variables that are written to inside this function
            state_variables_written = [
                v.name for v in function.all_state_variables_written() if v.name
            ]
            # 4) write everything to dict
            result['Contract']['Functions'].append({
                "Function": function.name,
                "Modifiers": listOfModifiers,
                "msg.sender_conditions": msg_sender_condition,
                "state_variables_written": state_variables_written
            })
    


# handling json        
with open("data.json","w") as file:
    json.dump(result, file, indent=4)