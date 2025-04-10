
def generate_contracts_table(contracts_object_list):
    """
    """
    md_content = "## Contracts\n| Contract Name | Address |\n"
    md_content += "|--------------|--------------|\n"
    
    for contract in contracts_object_list:
        md_content += f"| {contract['name']} | {contract['address']} |\n"
        try:
            md_content += f"| {contract['implementation_name']} | {contract['address']} |\n"
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
    """
    Generate the full markdown content including metadata, summary, overview, and tables.
    """
    metadata = "---\n"        
    metadata+="protocol: insert the name\n"
    metadata+="website: https://\n"
    metadata+="x: https://x.com/...\n"
    metadata+="github: https://github.com/\n"
    metadata+="defillama_slug: []\n"
    metadata+="chain: 'chain name'\n"
    metadata+="stage: 0|1|2\n"
    metadata+="reasons: []\n"
    metadata+="risks: ['L','L','L','L','L']\n"
    metadata+="author: ['author', 'co-author1', 'co-author2']\n"
    metadata+="submission_date: '1970-01-01'\n"
    metadata+="publish_date: '1970-01-01'\n"
    metadata+="update_date: '1970-01-01'\n"
    metadata+= "---\n"        
            
    summary = "# Summary\nAdd a summary of the protocols. What is it? What does it do? etc.\n"
            
    overview = "# Overview\n## Chain\n > Chain score: Low/Medium/High\n ## Upgradeability\n> Upgradeability score: Low/Medium/High\n## Autonomy\n> Autonomy score: Low/Medium/High\n## Exit Window\n> Exit Window score: Low/Medium/High\n## Accessibility\n> Accessibility score: Low/Medium/High\n "
            
    technical_analysis = "# Technical Analysis\n"

    permission_owner = "## Permission Owners \n"
    permission_owner += "| Name | Account | Type |\n"
    permission_owner += "|-------------|------------|-------------------------|\n"
    permission_owner += "|owner|0x|EOA/multisig/contract|\n"
    
    technical_analysis_addition = "## Dependencies\n## Exit Window\n"
            
    security_council = "# Security Council\n"

    security_council_table = "| ✅ /❌ | Requirement                                             |\n"
    security_council_table += "| ------ | ------------------------------------------------------- |\n"
    security_council_table += "| ❌     | At least 7 signers                                      |\n"
    security_council_table += "| ❌     | At least 51% threshold                                  |\n"
    security_council_table += "| ❌     | At least 50% non-insider signers                        |\n"
    security_council_table += "| ❌     | Signers are publicly announced (with name or pseudonym) |\n"
    
    return f"{metadata}\n{summary}\n{overview}\n\n{technical_analysis}\n{permission_owner}\n{generate_contracts_table(contracts)}\n\n{generate_permissions_table(permissions)}\n{technical_analysis_addition}\n{security_council}\n{security_council_table}"


