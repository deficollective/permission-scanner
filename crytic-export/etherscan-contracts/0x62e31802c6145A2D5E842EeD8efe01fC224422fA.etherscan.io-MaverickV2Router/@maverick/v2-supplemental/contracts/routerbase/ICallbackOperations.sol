// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IExactOutputSlim} from "./IExactOutputSlim.sol";

interface ICallbackOperations is IExactOutputSlim {
    /**
     * @notice Perform an exact output single swap.
     * @param recipient The address of the recipient.
     * @param pool The Maverick V2 pool to swap with.
     * @param tokenAIn A boolean indicating if token A is the input.
     * @param amountOut The amount of output tokens desired.
     * @param amountInMaximum The maximum amount of input tokens allowed.
     * @return amountIn The amount of input tokens used for the swap.
     * @return amountOut_ The actual amount of output tokens received.
     */
    function exactOutputSingle(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external payable returns (uint256 amountIn, uint256 amountOut_);

    /**
     * @notice Perform an output-specified single swap with tick limit check.
     * @param recipient The address of the recipient.
     * @param pool The Maverick V2 pool to swap with.
     * @param tokenAIn A boolean indicating if token A is the input.
     * @param amountOut The amount of output tokens desired.
     * @param tickLimit The tick limit for the swap.
     * @param amountInMaximum The maximum amount of input tokens allowed.
     * @param amountOutMinimum The minimum amount of output tokens expected.
     * @return amountIn_ The actual amount of input tokens used for the swap.
     * @return amountOut_ The actual amount of output tokens received.  This
     * amount can vary from the requested amountOut due to the tick limit.  If
     * the pool swaps to the tick limit, it will stop filling the order and
     * return the amount out swapped up to the ticklimit to the user.
     */
    function outputSingleWithTickLimit(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        int32 tickLimit,
        uint256 amountInMaximum,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountIn_, uint256 amountOut_);

    /**
     * @notice Perform an exact output multihop swap.
     * @param recipient The recipient address.
     * @param path The swap path as encoded bytes.
     * @param amountOut The exact output amount.
     * @param amountInMaximum The maximum input amount allowed.
     * @return amountIn The input amount for the swap.
     */
    function exactOutputMultiHop(
        address recipient,
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external payable returns (uint256 amountIn);

    /**
     * @notice Perform an input-specified single swap with tick limit check.
     * @param recipient The address of the recipient.
     * @param pool The Maverick V2 pool to swap with.
     * @param tokenAIn A boolean indicating if token A is the input.
     * @param amountIn The amount of input tokens.
     * @param tickLimit The tick limit for the swap.
     * @param amountOutMinimum The minimum amount of output tokens expected.
     * @return amountIn_ The actual input amount used for the swap. This may
     * differ from the amount the caller specified if the pool reaches the tick
     * limit.  In that case, the pool will consume the input swap amount up to
     * the tick limit and return the resulting output amount to the user.
     * @return amountOut The amount of output tokens received.
     */
    function inputSingleWithTickLimit(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountIn,
        int32 tickLimit,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountIn_, uint256 amountOut);
}
