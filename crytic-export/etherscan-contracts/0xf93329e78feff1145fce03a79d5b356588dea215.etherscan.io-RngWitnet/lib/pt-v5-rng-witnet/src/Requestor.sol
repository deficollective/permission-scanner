// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IWitnetRandomness } from "witnet/interfaces/IWitnetRandomness.sol";

/// @notice Thrown when a new random number is requested
error NotCreator();

/// @title Requestor
/// @author G9 Software Inc.
/// @notice A contract that requests random numbers from the Witnet Randomness Oracle. Holds the unused balance of Ether.
contract Requestor {

    /// @notice The address of the creator of the contract (RngWitnet)
    address public immutable creator;

    /// @notice Creates a new instance of the Requestor contract and sets the creator as the sender
    constructor() {
        creator = msg.sender;
    }

    /// @notice Requests a random number from the Witnet Randomness Oracle
    /// @dev You can send Ether along with this call
    /// @param value The amount of Ether to send to the Witnet Randomness Oracle
    /// @param _witnetRandomness The Witnet Randomness Oracle contract
    /// @return The actual value used by the Randomness Oracle
    function randomize(uint value, IWitnetRandomness _witnetRandomness) external payable onlyCreator returns (uint256) {
        uint cost = _witnetRandomness.randomize{ value: value }();
        return cost;
    }

    /// @notice Withdraws the balance of the contract to the specified address
    /// @dev can only be called the creator of the contract (RngWitnet)
    /// @param _to The address to which the balance will be sent
    /// @return The balance of the contract that was transferred
    function withdraw(address payable _to) external onlyCreator returns (uint256) {
        uint balance = address(this).balance;
        _to.transfer(balance);
        return balance;
    }

    /// @notice Allows receive of ether
    receive() payable external {}

    /// @notice Modifier to only allow calls by the creator
    modifier onlyCreator() {
        if(msg.sender != address(creator)) {
            revert NotCreator();
        }
        _;
    }
}
