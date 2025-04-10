
def generate_contracts_table(contracts_object_list):
    """
    """
    md_content = "## Contracts\n| Contract Name | Address |\n"
    md_content += "|--------------|--------------|\n"
    
    for contract in contracts_object_list:
        md_content += f"| {contract['name']} | {contract['address']} |\n"
        try:
            md_content += f"| {contract['implementation_name']} | ... |\n"
        except KeyError:
            # not a proxy but a standard contract
            pass
    
    return md_content

def generate_permissions_table(permissions):
    """
    """
    md_content = "## Permission\n| Contract | Function | Impact | Owner |\n"
    md_content += "|-------------|------------|-------------------------|-------------------|\n"
    
    for contract, entries in permissions.items():
        try:
            proxy_permissions = entries["proxy_permissions"]
            contract_name = proxy_permissions["Contract_Name"]
            permissioned_functions = proxy_permissions["Functions"]
            for permissioned_function in permissioned_functions:
                owner = ""
                try:
                    owner = permissioned_function['_owner']
                except KeyError:
                    owner = permissioned_function['Modifiers']
                    pass
               
                md_content += f"| {contract_name} | {permissioned_function['Function']} | ... | {owner} |\n"
        except KeyError:
            # just a normal contract
            pass
        # will do the normal contract or the implementation contract
        proxy_permissions = entries["permissions"]
        contract_name = proxy_permissions["Contract_Name"]
        permissioned_functions = proxy_permissions["Functions"]
        for permissioned_function in permissioned_functions:
            owner = ""
            try:
                owner = permissioned_function['_owner']
            except KeyError:
                # no simple owner found
                owner = permissioned_function['Modifiers']
                pass
            
            md_content += f"| {contract_name} | {permissioned_function['Function']} | ... | {owner} |\n"
    
    return md_content

def generate_full_markdown(protocol_metadata, contracts, permissions) -> str:
    
    return f"{generate_contracts_table(contracts)}\n\n{generate_permissions_table(permissions)}"


