// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILiquidationSource } from "./ILiquidationSource.sol";

interface ILiquidationPair {

  /**
   * @notice The liquidation source that the pair is using.
   * @dev The source executes the actual token swap, while the pair handles the pricing.
   */
  function source() external returns (ILiquidationSource);

  /**
   * @notice Returns the token that is used to pay for auctions.
   * @return address of the token coming in
   */
  function tokenIn() external returns (address);

  /**
   * @notice Returns the token that is being auctioned.
   * @return address of the token coming out
   */
  function tokenOut() external returns (address);

  /**
   * @notice Get the address that will receive `tokenIn`.
   * @return Address of the target
   */
  function target() external returns (address);

  /**
   * @notice Gets the maximum amount of tokens that can be swapped out from the source.
   * @return The maximum amount of tokens that can be swapped out.
   */
  function maxAmountOut() external returns (uint256);

  /**
   * @notice Swaps the given amount of tokens out and ensures the amount of tokens in doesn't exceed the given maximum.
   * @dev The amount of tokens being swapped in must be sent to the target before calling this function.
   * @param _receiver The address to send the tokens to.
   * @param _amountOut The amount of tokens to receive out.
   * @param _amountInMax The maximum amount of tokens to send in.
   * @param _flashSwapData If non-zero, the _receiver is called with this data prior to
   * @return The amount of tokens sent in.
   */
  function swapExactAmountOut(
    address _receiver,
    uint256 _amountOut,
    uint256 _amountInMax,
    bytes calldata _flashSwapData
  ) external returns (uint256);

  /**
   * @notice Computes the exact amount of tokens to send in for the given amount of tokens to receive out.
   * @param _amountOut The amount of tokens to receive out.
   * @return The amount of tokens to send in.
   */
  function computeExactAmountIn(uint256 _amountOut) external returns (uint256);
}
