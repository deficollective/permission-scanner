def generate_prompt(json_object):
    json_prompt = {}
    json_prompt["Overview"] = {
        "Chain": {
            "Text": "",
            "Score": ""
        },
        "Upgradeability": {
            "Text": "",
            "Score": ""
        },
        "Autonomy": {
            "Text": "",
            "Score": ""
        },
        "Exit Window": {
            "Text": "",
            "Score": ""
        },
        "Accessibility": {
            "Text": "",
            "Score": ""
        }
    }

    json_prompt["Detailed Analysis"] = []

    for key, contract_scan_object in json_object.items():
        try:
            proxy_permission = contract_scan_object["proxy_permissions"]
            for function in proxy_permission["Functions"]:
                element = {
                    "Contract": proxy_permission["Contract_Name"],
                    "Function": function["Function"],
                    "Impact": "",
                    "Owner": ""
                }
            json_prompt["Detailed Analysis"].append(element)
        except Exception: 
            pass
        permissions = contract_scan_object["permissions"]
        for function in permissions["Functions"]:
            element = {
                "Contract": permissions["Contract_Name"],
                "Function": function["Function"],
                "Impact": "",
                "Owner": ""
            }
            json_prompt["Detailed Analysis"].append(element)
    
    return json_prompt

