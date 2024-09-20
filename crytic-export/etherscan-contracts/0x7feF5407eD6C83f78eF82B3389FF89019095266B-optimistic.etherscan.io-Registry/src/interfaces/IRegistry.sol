// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IRegistry {
    error AlreadyApproved();
    error NotApproved();
    error ZeroAddress();
    error NotTeam();

    event Approve(address indexed element);
    event Unapprove(address indexed element);

    /// @notice Approves the given address
    ///         Cannot approve address(0).
    ///         Cannot approve an address that is already approved.
    /// @dev Callable by onlyOwner
    /// @param element address to be approved
    function approve(address element) external;

    /// @notice Revokes the permission from the given address
    ///         Cannot unapprove an address that is not approved.
    /// @dev Callable by onlyOwner
    /// @param element address to be approved
    function unapprove(address element) external;

    /// @notice Get all addresses approved by the registry
    function getAll() external view returns (address[] memory);

    /// @notice Check if an address is approved within the Registry.
    /// @param element address to check in registry.
    /// @return True if address is approved, else false
    function isApproved(address element) external view returns (bool);

    /// @notice Get the length of the stored addresses array
    function length() external view returns (uint256);
}
