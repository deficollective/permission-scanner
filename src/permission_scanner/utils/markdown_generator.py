from typing import List, Dict, Any
import datetime


def generate_contracts_table(
    contract_data: List[Dict[str, str]], scan_results: Dict[str, Any]
) -> str:
    """Generate the contracts overview table.

    Args:
        contract_data (List[Dict[str, str]]): List of contract metadata
        scan_results (Dict[str, Any]): Results from contract scanning

    Returns:
        str: Markdown table of contracts
    """
    content = []
    content.append("## Contracts")
    content.append("\n| Contract Name | Address | Type |")
    content.append("|--------------|---------|------|")

    for contract in contract_data:
        contract_name = contract["name"]
        address = contract["address"]
        contract_type = (
            "Proxy"
            if scan_results.get(contract_name, {}).get("Proxy_Address")
            else "Implementation"
        )
        content.append(f"| {contract_name} | {address} | {contract_type} |")

    return "\n".join(content)


def generate_permissions_table(scan_results: Dict[str, Any]) -> str:
    """Generate the permissions table.

    Args:
        scan_results (Dict[str, Any]): Results from contract scanning

    Returns:
        str: Markdown table of permissions
    """
    content = []
    content.append("\n## Permissions")
    content.append("\n| Contract | Function | Impact | Owner |")
    content.append("|----------|----------|---------|-------|")

    for contract_name, contract_data in scan_results.items():
        # Handle proxy permissions if they exist
        if "proxy_permissions" in contract_data:
            proxy_permissions = contract_data["proxy_permissions"]
            for function in proxy_permissions.get("Functions", []):
                owner = function.get("Modifiers", [])
                if not owner and "_owner" in function:
                    owner = function["_owner"]
                content.append(
                    f"| {proxy_permissions['Contract_Name']} | {function['Function']} | ... | {owner} |"
                )

        # Handle implementation permissions
        if "permissions" in contract_data:
            permissions = contract_data["permissions"]
            for function in permissions.get("Functions", []):
                owner = function.get("Modifiers", [])
                if not owner and "_owner" in function:
                    owner = function["_owner"]
                content.append(
                    f"| {permissions['Contract_Name']} | {function['Function']} | ... | {owner} |"
                )

    return "\n".join(content)


def generate_full_markdown(
    project_name: str, contract_data: List[Dict[str, str]], scan_results: Dict[str, Any]
) -> str:
    """Generate a full markdown report from scan results.

    Args:
        project_name (str): Name of the project being scanned
        contract_data (List[Dict[str, str]]): List of contract metadata
        scan_results (Dict[str, Any]): Results from contract scanning

    Returns:
        str: Generated markdown content
    """
    content = []

    # Add header
    content.append("# Permission Scanner Report")
    content.append(
        f"\nGenerated on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    content.append(f"Project: {project_name}\n")

    # Generate tables
    content.append(generate_contracts_table(contract_data, scan_results))
    content.append(generate_permissions_table(scan_results))

    return "\n".join(content)
