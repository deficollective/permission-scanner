// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IRegistry} from "./interfaces/IRegistry.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title Protocol Registry
/// @author velodrome.finance, @airtoonricardo, @pedrovalido
/// @notice Protocol Registry to manage approved addresses
contract Registry is IRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Array of address used to store approved addresses
    EnumerableSet.AddressSet internal _registry;

    constructor(address[] memory approved) {
        for (uint256 i = 0; i < approved.length; i++) {
            _approve(approved[i]);
        }
    }

    /// @inheritdoc IRegistry
    function approve(address element) public virtual onlyOwner {
        _approve(element);
    }

    // @dev Private approve function to be used in constructor
    function _approve(address element) private {
        if (element == address(0)) revert ZeroAddress();
        if (_registry.contains(element)) revert AlreadyApproved();

        _registry.add(element);
        emit Approve(element);
    }

    /// @inheritdoc IRegistry
    function unapprove(address element) external virtual onlyOwner {
        if (!_registry.contains(element)) revert NotApproved();

        _registry.remove(element);
        emit Unapprove(element);
    }

    /// @inheritdoc IRegistry
    function getAll() external view returns (address[] memory) {
        return _registry.values();
    }

    /// @inheritdoc IRegistry
    function isApproved(address element) external view returns (bool) {
        return _registry.contains(element);
    }

    /// @inheritdoc IRegistry
    function length() external view returns (uint256) {
        return _registry.length();
    }
}
