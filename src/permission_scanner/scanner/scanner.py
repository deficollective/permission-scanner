from typing import List, Dict, Any, Tuple
import urllib.error
import re
import json
from slither import Slither
from slither.core.declarations.function import Function
from slither.core.declarations.contract import Contract
from slither.tools.read_storage.read_storage import (
    SlitherReadStorage,
    RpcInfo,
    get_storage_data,
)

from ..utils.block_explorer import BlockExplorer


class ContractScanner:
    """Service for scanning smart contracts for permissions and storage."""

    def __init__(
        self,
        chain_name: str,
        project_name: str,
        address: str,
        block_explorer_api_key: str,
        rpc_url: str,
        export_dir: str = "results",
    ):
        """Initialize the ContractScanner.

        Args:
            rpc_url (str): The RPC URL for the blockchain network
            block_explorer (BlockExplorer): The block explorer instance for fetching contract metadata
            export_dir (str): Directory to save Solidity files and crytic_compile.config.json
        """
        self.project_name = project_name
        self.address = address
        self.chain_name = chain_name
        self.block_explorer_api_key = block_explorer_api_key
        self.rpc_url = rpc_url
        self.export_dir = export_dir
        self.permissions_results = {}
        self.target_storage_vars = []
        self.contract_data_for_markdown = []
        self.scan_result = {}
        self.implementation_name = None
        self.block_explorer = BlockExplorer(
            api_key=self.block_explorer_api_key, chain_name=chain_name
        )

    @staticmethod
    def _is_valid_eth_address(address: str) -> bool:
        """Check if a string is a valid Ethereum address."""
        return bool(re.fullmatch(r"0x[a-fA-F0-9]{40}", address))

    @staticmethod
    def _get_msg_sender_checks(function: Function) -> List[str]:
        """Get all msg.sender checks in a function and its internal calls."""
        all_functions = (
            [f for f in function.all_internal_calls() if isinstance(f, Function)]
            + [
                m
                for f in function.all_internal_calls()
                if isinstance(f, Function)
                for m in f.modifiers
            ]
            + [function]
            + [m for m in function.modifiers if isinstance(m, Function)]
            + [
                call
                for call in function.all_library_calls()
                if isinstance(call, Function)
            ]
            + [
                m
                for call in function.all_library_calls()
                if isinstance(call, Function)
                for m in call.modifiers
            ]
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

    def _scan_permissions(self, contract: Contract) -> Dict[str, Any]:
        """Analyze permissions in a contract and store results.

        Args:
            contract (Contract): The contract to analyze
            all_state_variables_read (List[str]): List of state variables read
            is_proxy (bool): Whether the contract is a proxy
            index (int): Index for proxy/implementation contract
        """
        result_dict = {"Contract_Name": contract.name, "Functions": []}

        for function in contract.functions:
            # Get all modifiers
            modifiers = function.modifiers
            for call in function.all_internal_calls():
                if isinstance(call, Function):
                    modifiers += call.modifiers
            for call in function.all_library_calls():
                if isinstance(call, Function):
                    modifiers += call.modifiers

            list_of_modifiers = sorted([m.name for m in set(modifiers)])

            # Get msg.sender conditions
            msg_sender_condition = self._get_msg_sender_checks(function)

            if len(modifiers) == 0 and len(msg_sender_condition) == 0:
                continue

            # Get state variables read
            state_variables_read_inside_modifiers = [
                v.name
                for modifier in modifiers
                if modifier is not None
                for v in modifier.all_variables_read()
                if v is not None and v.name
            ]

            state_variables_read_inside_function = [
                v.name for v in function.all_state_variables_read() if v.name
            ]

            all_state_variables_read_this_func = []
            all_state_variables_read_this_func.extend(
                state_variables_read_inside_modifiers
            )
            all_state_variables_read_this_func.extend(
                state_variables_read_inside_function
            )
            all_state_variables_read_this_func = list(
                set(all_state_variables_read_this_func)
            )

            self.target_storage_vars.extend(all_state_variables_read_this_func)

            # Get state variables written
            state_variables_written = [
                v.name for v in function.all_state_variables_written() if v.name
            ]

            # Store results
            result_dict["Functions"].append(
                {
                    "Function": function.name,
                    "Modifiers": list_of_modifiers,
                    "msg.sender_conditions": msg_sender_condition,
                    "state_variables_read": all_state_variables_read_this_func,
                    "state_variables_written": state_variables_written,
                }
            )

        return result_dict

    def _scan_storage(
        self,
        storage_scanner: SlitherReadStorage,
        permissions_result: Dict[str, Any],
        contract_address: str,
    ) -> Dict[str, Any]:
        """Scan contract storage.

        Args:
            storage_scanner (SlitherReadStorage): Initialized storage scanner
            permissions_result (Dict[str, Any]): Results from permission scan
            contract_address (str): Contract address to scan

        Returns:
            Dict[str, Any]: Storage analysis results
        """
        # sets target variables
        # adapted logic, extracted from method `get_all_storage_variables` of SlitherReadStorage class
        for contract in storage_scanner._contracts:
            for var in contract.state_variables_ordered:
                if var.name in self.target_storage_vars:
                    # achieve step 1.
                    storage_scanner._target_variables.append((contract, var))

                # add all constant and immutable variable to a list to do the required look-up
                if not var.is_stored:

                    # functionData is a dict
                    for functionData in permissions_result["Functions"]:
                        # check if e.g storage variable owner is part of this function
                        if var.name in functionData["state_variables_read"]:
                            # check if already added some constants/immutables

                            # Ensure key exists
                            if "immutables_and_constants" not in functionData:
                                functionData["immutables_and_constants"] = []

                            # Check if the variable has an expression and is not the proxy marker
                            if (
                                var.expression
                                and str(var.expression)
                                != "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
                            ):
                                try:
                                    raw_value = get_storage_data(
                                        storage_scanner.rpc_info.web3,
                                        contract_address,
                                        str(var.expression),
                                        storage_scanner.rpc_info.block,
                                    )
                                    value = storage_scanner.convert_value_to_type(
                                        raw_value, 160, 0, "address"
                                    )
                                    functionData["immutables_and_constants"].append(
                                        {
                                            "name": var.name,
                                            "slot": str(var.expression),
                                            "value": value,
                                        }
                                    )
                                except Exception:
                                    functionData["immutables_and_constants"].append(
                                        {"name": var.name, "slot": str(var.expression)}
                                    )
                            else:
                                functionData["immutables_and_constants"].append(
                                    {"name": var.name}
                                )

        # step 2. computes storage keys for target variables
        storage_scanner.get_target_variables()

        # step 3. get the values of the target variables and their slots
        try:
            storage_scanner.walk_slot_info(storage_scanner.get_slot_values)
        except urllib.error.HTTPError as e:
            print(
                f"\033[33mFailed to fetch storage from contract at {contract_address} due to HTTP error: {e}\033[0m"
            )
        except Exception as e:
            print(
                f"\033[33mAn error occurred while fetching storage slots from contract {contract_address}: {e}\033[0m"
            )

        storageValues = {}
        # merge storage retrieval with contracts
        for key, value in storage_scanner.slot_info.items():
            contractDict = permissions_result
            storageValues[value.name] = value.value
            # contractDict["Functions"] is a list, functionData a dict
            for functionData in contractDict["Functions"]:
                # check if e.g storage variable owner is part of this function
                if value.name in functionData["state_variables_read"]:
                    # if so, add a key value pair to the functionData object, to improve readability of report
                    functionData[value.name] = value.value

        return storageValues

    def _check_proxy(self, contract_metadata: Dict[str, Any]):
        """Handle proxy contract logic.

        Args:
            contract_metadata (Dict[str, Any]): Metadata of the contract

        Returns:
            tuple: (isProxy, implementation_address)
        """
        isProxy = contract_metadata["Proxy"] == 1
        implementation_address = contract_metadata["Implementation"]
        implementation_name = None

        if isProxy and implementation_address:
            if not isinstance(
                implementation_address, str
            ) or not self._is_valid_eth_address(implementation_address):
                raise ValueError(
                    f"Invalid implementation address for proxy: {implementation_address}"
                )
            try:
                implementation_result = self.block_explorer.get_contract_metadata(
                    implementation_address
                )
                implementation_name = implementation_result.get("ContractName", None)
                self.implementation_name = implementation_name
                self.contract_data_for_markdown.append(
                    {"name": implementation_name, "address": implementation_address}
                )
            except Exception as e:
                raise f"Failed to get Implementation contract from Etherscan. \n\n\n  + {e}"

    def scan(self) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
        """Scan a contract for permissions and storage.

        Args:
            contract_address (str): The contract address to scan

        Returns:
            Dict[str, Any]: The scan results containing permissions and storage analysis
        """
        final_scan_result = {}
        contract_metadata = self.block_explorer.get_contract_metadata(self.address)
        with open(
            f"{self.export_dir}/{self.project_name}-contracts/contract_metadata.json",
            "w",
        ) as f:
            json.dump(contract_metadata, f)
        contract_name = contract_metadata["ContractName"]
        isProxy = contract_metadata["Proxy"] == 1

        self.contract_name = contract_name
        self.contract_data_for_markdown.append(
            {"name": contract_name, "address": self.address}
        )
        self._check_proxy(contract_metadata)

        # Initialize scan_result structure
        self.scan_result[contract_name] = {}

        slither = Slither(
            f"{self.chain_name}:{self.address}",
            export_dir=f"{self.export_dir}/{self.project_name}-contracts/{contract_name}",
            allow_path=f"{self.export_dir}/{self.project_name}-contracts",
        )

        # Get target contract from slither
        target_contract = [c for c in slither.contracts if c.name == contract_name]
        if not target_contract:
            raise ValueError(f"Contract {contract_name} not found in source code")

        # Initialize storage scanner
        rpc_info = RpcInfo(self.rpc_url, "latest")
        srs = SlitherReadStorage(target_contract, max_depth=5, rpc_info=rpc_info)
        srs.unstructured = False
        srs.storage_address = self.address

        # If proxy, scan implementation
        if isProxy:
            impl_address = contract_metadata["Implementation"]
            impl_slither = Slither(
                f"{self.chain_name}:{impl_address}",
                export_dir=f"{self.export_dir}/{self.project_name}-contracts/{self.implementation_name}",
                allow_path=f"{self.export_dir}/{self.project_name}-contracts",
            )
            # Get implementation contract
            impl_contracts = impl_slither.contracts_derived

            # find the instantiated/main implementation contract
            target_contract.extend(
                [
                    contract
                    for contract in impl_contracts
                    if contract.name == self.implementation_name
                ]
            )
            if len(target_contract) == 1:
                raise Exception(
                    f"\033[31m\n \nThe implementation name supplied in contract.json does not match any of the found implementation contract names for this address: {self.address}\033[0m"
                )
            self.scan_result["Implementation_Address"] = impl_address
            self.scan_result["Proxy_Address"] = self.address
        if not isProxy:
            self.scan_result["Address"] = self.address

        for i, contract in enumerate(target_contract):
            # get permissions and store inside target_storage_vars
            _scan_permissions_result = self._scan_permissions(contract)
            if isProxy and i == 0:
                self.scan_result["proxy_permissions"] = _scan_permissions_result
            else:
                self.scan_result["permissions"] = _scan_permissions_result

        self.target_storage_vars = list(
            set(self.target_storage_vars)
        )  # remove duplicates

        # Scan storage
        permissions_result = self.scan_result["permissions"]
        storage_result = self._scan_storage(srs, permissions_result, self.address)
        if len(storage_result.values()):
            self.scan_result["storage_values"] = storage_result

        if self.implementation_name:
            final_scan_result[self.implementation_name] = self.scan_result
        else:
            final_scan_result[self.contract_name] = self.scan_result

        return final_scan_result, self.contract_data_for_markdown
