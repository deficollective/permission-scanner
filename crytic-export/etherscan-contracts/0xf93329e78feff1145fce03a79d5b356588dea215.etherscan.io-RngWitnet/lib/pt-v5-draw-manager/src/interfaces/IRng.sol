// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRng - interface for Random Number Generators
/// @dev This is a simple interface to allow DrawManager to interact with a Random Number Generator
interface IRng {
    /// @notice Returns the block number at which an rng request was made
    /// @param rngRequestId The RNG request id
    /// @return The block number at which the request was made
    function requestedAtBlock(uint32 rngRequestId) external returns (uint256);

    /// @notice Returns whether the RNG request is complete and the random number is available
    /// @param rngRequestId The RNG request id
    /// @return True if the random number is available, false otherwise
    function isRequestComplete(uint32 rngRequestId) external view returns (bool);

    /// @notice Returns whether the RNG request failed
    /// @param rngRequestId The RNG request id
    /// @return True if the request failed, false otherwise
    function isRequestFailed(uint32 rngRequestId) external view returns (bool);

    /// @notice Returns the random number for a given request
    /// @param rngRequestId The RNG request id
    /// @return The random number
    function randomNumber(uint32 rngRequestId) external returns (uint256);
}
