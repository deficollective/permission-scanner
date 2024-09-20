// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IRouterErrors} from "./IRouterErrors.sol";

interface IPushOperations is IRouterErrors {
    /**
     * @notice Perform an exact input single swap with compressed input values.
     */
    function exactInputSinglePackedArgs(bytes memory argsPacked) external payable returns (uint256 amountOut);

    /**
     * @notice Perform an exact input single swap without tick limit check.
     * @param recipient The address of the recipient.
     * @param pool The Maverick V2 pool to swap with.
     * @param tokenAIn True is tokenA is the input token.  False is tokenB is
     * the input token.
     * @param amountIn The amount of input tokens.
     * @param amountOutMinimum The minimum amount of output tokens expected.
     */
    function exactInputSingle(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountOut);

    /**
     * @notice Perform an exact input multi-hop swap.
     * @param recipient The address of the recipient.
     * @param path The path of tokens to swap.
     * @param amountIn The amount of input tokens.
     * @param amountOutMinimum The minimum amount of output tokens expected.
     */
    function exactInputMultiHop(
        address recipient,
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountOut);
}
