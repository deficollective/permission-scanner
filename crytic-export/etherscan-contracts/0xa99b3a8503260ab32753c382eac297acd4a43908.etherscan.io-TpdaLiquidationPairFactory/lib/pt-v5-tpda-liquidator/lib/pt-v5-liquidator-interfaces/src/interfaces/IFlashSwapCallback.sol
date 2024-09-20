// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the flash swap callback
interface IFlashSwapCallback {

    /// @notice Called on the token receiver by the LiquidationPair during a liquidation if the flashSwap data length is non-zero
    /// @param _sender The address that triggered the liquidation swap
    /// @param _amountOut The amount of tokens that were sent to the receiver
    /// @param _amountIn The amount of tokens expected to be sent to the target
    /// @param _flashSwapData The flash swap data that was passed into the swap function.
    function flashSwapCallback(
        address _sender,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes calldata _flashSwapData
    ) external;
}
