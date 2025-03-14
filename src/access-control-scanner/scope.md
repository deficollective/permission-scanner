# access-control-scanner

# scope

This is the scope of the access control scanner.

Inside main.py a functional program is run.

It uses:

- web3py

It requires the following arguments via the command line:

- contract_address
- chain_name
- starting block (when was the contract deployed)

constants in the program and required variables:

- signature of the following events:
  - event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  - event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  - event RoleAdminChanged(
    bytes32 indexed role,
    bytes32 indexed previousAdminRole,
    bytes32 indexed newAdminRole
    );
- rpc url from env file (it uses get_rpc_url function)

It does the following steps:

1. it sets up a data structure to store the temporary results (it's called `temp`)
2. it runs through the chain history from starting block to the current block
   - it makes sure that it doesn't hit the limits of the rpc provider (throttling)
3. it reads the events from the block and updates the data structure (see below)
4. after arriving at the current block it creates a second data structure to store the following results (called `result`)
   - the data structure is a dictionary with the following structure:
   - top level key is bytes32 role (all the different roles have different bytes32 values)
   - top level value is a list of addresses owning the role
   - the computation to achieve this is the following:
     - for each event in the data structure `temp`
       - if the event is a RoleGranted event
         - add the address to the list of addresses owning the role
       - if the event is a RoleRevoked event
         - remove the address from the list of addresses owning the role
5. it writes both data structures to two different files

the data structure of `temp` is a dictionary with the following structure:

- top level key is bytes32 role (all the different roles have different bytes32 values)
- top level value (paired with bytes32 role) is a list of dictionaries with the following structure:
  - keys:
    - block
    - address
    - action (granted or revoked) (of type enum)

example of the data structure of `temp`:

```json
{
  "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b": [
    {
      "block": 123456,
      "address": "0x1234567890123456789012345678901234567890",
      "action": "granted"
    },
    {
      "block": 123457,
      "address": "0x1234567890123456789012345678901234567890",
      "action": "revoked"
    }
  ]
}
```

example of the data structure of `result`:

```json
{
  "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b": [
    "0x5b6d8aa9bedce4120d25132fb291f4bb9e857026",
    "0xc2aacf6553d20d1e9d78e365aaba8032af9c85b0"
  ],
  "0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278": [
    "0x1234567890123456789012345678901234567890"
  ]
}
```
