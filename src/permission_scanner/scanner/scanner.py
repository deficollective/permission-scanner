import json
from typing import List, Dict, Any
import urllib.error
import os
import re

from slither.slither import Slither
from slither.core.declarations.function import Function
from slither.core.declarations.contract import Contract
from slither.tools.read_storage.read_storage import (
    SlitherReadStorage,
    RpcInfo,
    get_storage_data,
)

from ..utils.block_explorer import BlockExplorer
from ..utils.logger import setup_logger
from ..utils.markdown_generator import generate_full_markdown

logger = setup_logger(__name__, "logs/scanner_new.log")


class ContractScanner:
    """Service for scanning smart contracts for permissions and storage."""

    def __init__(
        self, rpc_url: str, block_explorer: BlockExplorer, export_dir: str = "results"
    ):
        """Initialize the ContractScanner.

        Args:
            rpc_url (str): The RPC URL for the blockchain network
            block_explorer (BlockExplorer): The block explorer instance for fetching contract metadata
            export_dir (str): Directory to save Solidity files and crytic_compile.config.json
        """
        self.rpc_url = rpc_url
        self.block_explorer = block_explorer
        self.slither = None
        self.storage_reader = None
        self.export_dir = export_dir
        self.contract_data_for_markdown = []
        self.scan_results = {}
        logger.info("Initialized ContractScanner")

    @staticmethod
    def is_valid_eth_address(address: str) -> bool:
        """Check if a string is a valid Ethereum address."""
        return bool(re.fullmatch(r"0x[a-fA-F0-9]{40}", address))

    @staticmethod
    def get_msg_sender_checks(function: Function) -> List[str]:
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

    def get_permissions(
        self,
        contract: Contract,
        result: Dict[str, Any],
        all_state_variables_read: List[str],
        is_proxy: bool,
        index: int,
    ) -> None:
        """Analyze permissions in a contract and store results.

        Args:
            contract (Contract): The contract to analyze
            result (Dict[str, Any]): Dictionary to store results
            all_state_variables_read (List[str]): List of state variables read
            is_proxy (bool): Whether the contract is a proxy
            index (int): Index for proxy/implementation contract
        """
        temp = {"Contract_Name": contract.name, "Functions": []}

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
            msg_sender_condition = self.get_msg_sender_checks(function)

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

            all_state_variables_read.extend(all_state_variables_read_this_func)

            # Get state variables written
            state_variables_written = [
                v.name for v in function.all_state_variables_written() if v.name
            ]

            # Store results
            temp["Functions"].append(
                {
                    "Function": function.name,
                    "Modifiers": list_of_modifiers,
                    "msg.sender_conditions": msg_sender_condition,
                    "state_variables_read": all_state_variables_read_this_func,
                    "state_variables_written": state_variables_written,
                }
            )

        # Store in result dict
        if is_proxy and index == 0:
            result["proxy_permissions"] = temp
        elif is_proxy and index == 1:
            result["permissions"] = temp
        else:
            result["permissions"] = temp

    def scan_contract(self, address: str) -> Dict[str, Any]:
        """Scan a contract for permissions and storage.

        Args:
            address (str): The contract address to scan

        Returns:
            Dict[str, Any]: The scan results for this contract
        """
        logger.info(f"Starting scan for contract at {address}")

        try:
            # Fetch contract metadata
            contract_result = self.block_explorer.fetch_contract_metadata(address)
            contract_name = contract_result["ContractName"]
            is_proxy = contract_result["Proxy"] == 1
            implementation_address = contract_result["Implementation"]
            implementation_name = ""

            # Add contract to markdown data
            self.contract_data_for_markdown.append(
                {"name": contract_name, "address": address}
            )

            result = {}
            target_storage_vars = []
            temp_global = {}

            # Setup RPC info
            rpc_info = RpcInfo(self.rpc_url, "latest")

            # Create etherscan-contracts directory for this contract
            contract_dir = os.path.join(self.export_dir, contract_name)
            os.makedirs(contract_dir, exist_ok=True)

            # Handle proxy contracts
            if is_proxy and implementation_address:
                if not self.is_valid_eth_address(implementation_address):
                    raise ValueError(
                        f"Invalid implementation address for proxy: {implementation_address}"
                    )

                try:
                    implementation_result = self.block_explorer.fetch_contract_metadata(
                        implementation_address
                    )
                    implementation_name = implementation_result.get("ContractName", "")

                    # Add implementation contract to markdown data
                    if implementation_name:
                        self.contract_data_for_markdown.append(
                            {
                                "name": implementation_name,
                                "address": implementation_address,
                            }
                        )
                except Exception as e:
                    raise RuntimeError(f"Failed to get Implementation contract: {e}")

            # Initialize Slither with export directory
            try:
                self.slither = Slither(
                    f"{self.block_explorer.chain_name}:{address}",
                    export_dir=contract_dir,
                    etherscan_api_key=self.block_explorer.api_key,
                )
            except urllib.error.HTTPError as e:
                logger.error(
                    f"Failed to compile contract at {address} due to HTTP error: {e}"
                )
                raise
            except Exception as e:
                logger.error(f"An error occurred while analyzing {address}: {e}")
                raise

            # Get target contract
            contracts = self.slither.contracts
            target_contract = [c for c in contracts if c.name == contract_name]

            if not target_contract:
                raise ValueError(
                    f"Contract name {contract_name} not found at address {address}"
                )

            # Initialize storage reader
            self.storage_reader = SlitherReadStorage(target_contract, 10, rpc_info)
            self.storage_reader.unstructured = False
            address = address[address.find(":") + 1 :] if ":" in address else address
            self.storage_reader.storage_address = address

            # Handle proxy implementation
            if is_proxy:
                # Use the same directory for implementation contract
                self.slither = Slither(
                    f"{self.block_explorer.chain_name}:{implementation_address}",
                    export_dir=contract_dir,
                    etherscan_api_key=self.block_explorer.api_key,
                )
                implementation_contracts = self.slither.contracts_derived
                target_contract.extend(
                    [
                        c
                        for c in implementation_contracts
                        if c.name == implementation_name
                    ]
                )

                if len(target_contract) == 1:
                    raise ValueError(
                        f"Implementation name {implementation_name} not found"
                    )

                temp_global["Implementation_Address"] = implementation_address
                temp_global["Proxy_Address"] = address
            else:
                temp_global["Address"] = address

            # Analyze permissions
            for i, contract in enumerate(target_contract):
                self.get_permissions(
                    contract, temp_global, target_storage_vars, is_proxy, i
                )

            target_storage_vars = list(set(target_storage_vars))

            # Read storage
            self._read_storage(
                target_contract, target_storage_vars, temp_global, address
            )

            # Store results
            if implementation_name:
                self.scan_results[implementation_name] = temp_global
            else:
                self.scan_results[contract_name] = temp_global

            logger.info(f"Completed scan for contract {contract_name}")
            return temp_global

        except Exception as e:
            logger.error(
                f"Unexpected error while scanning contract {address}: {str(e)}"
            )
            raise

    def _read_storage(
        self,
        target_contract: List[Contract],
        target_storage_vars: List[str],
        temp_global: Dict[str, Any],
        contract_address: str,
    ) -> None:
        """Read storage values for the contract.

        Args:
            target_contract (List[Contract]): List of contracts to analyze
            target_storage_vars (List[str]): List of storage variables to read
            temp_global (Dict[str, Any]): Dictionary to store results
            contract_address (str): The contract address
        """
        # Set target variables
        for contract in self.storage_reader._contracts:
            for var in contract.state_variables_ordered:
                if var.name in target_storage_vars:
                    self.storage_reader._target_variables.append((contract, var))

                if not var.is_stored:
                    for function_data in temp_global["permissions"]["Functions"]:
                        if var.name in function_data["state_variables_read"]:
                            if "immutables_and_constants" not in function_data:
                                function_data["immutables_and_constants"] = []

                            if (
                                var.expression
                                and str(var.expression)
                                != "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
                            ):
                                try:
                                    raw_value = get_storage_data(
                                        self.storage_reader.rpc_info.web3,
                                        contract_address,
                                        str(var.expression),
                                        self.storage_reader.rpc_info.block,
                                    )
                                    value = self.storage_reader.convert_value_to_type(
                                        raw_value, 160, 0, "address"
                                    )
                                    function_data["immutables_and_constants"].append(
                                        {
                                            "name": var.name,
                                            "slot": str(var.expression),
                                            "value": value,
                                        }
                                    )
                                except Exception:
                                    function_data["immutables_and_constants"].append(
                                        {"name": var.name, "slot": str(var.expression)}
                                    )
                            else:
                                function_data["immutables_and_constants"].append(
                                    {"name": var.name}
                                )

        # Compute storage keys and get values
        self.storage_reader.get_target_variables()
        try:
            self.storage_reader.walk_slot_info(self.storage_reader.get_slot_values)
        except Exception as e:
            logger.error(f"Failed to read storage: {e}")
            raise

        # Store storage values
        storage_values = {}
        for key, value in self.storage_reader.slot_info.items():
            contract_dict = temp_global["permissions"]
            storage_values[value.name] = value.value

            for function_data in contract_dict["Functions"]:
                if value.name in function_data["state_variables_read"]:
                    function_data[value.name] = value.value

        if storage_values:
            contract_dict["storage_values"] = storage_values

    def generate_reports(self, project_name: str) -> None:
        """Generate JSON and markdown reports from scan results.

        Args:
            project_name (str): Name of the project being scanned
        """
        # Create reports directory
        reports_dir = os.path.join(self.export_dir, "reports")
        os.makedirs(reports_dir, exist_ok=True)

        # Save JSON report
        json_path = os.path.join(reports_dir, f"permissions_{project_name}.json")
        with open(json_path, "w") as f:
            json.dump(self.scan_results, f, indent=4)
        logger.info(f"Generated JSON report: {json_path}")

        # Generate and save markdown report
        markdown_content = generate_full_markdown(
            project_name, self.contract_data_for_markdown, self.scan_results
        )
        markdown_path = os.path.join(reports_dir, f"permissions_{project_name}.md")
        with open(markdown_path, "w") as f:
            f.write(markdown_content)
        logger.info(f"Generated Markdown report: {markdown_path}")

    def get_scan_results(self) -> Dict[str, Any]:
        """Get the current scan results.

        Returns:
            Dict[str, Any]: The accumulated scan results
        """
        return self.scan_results
