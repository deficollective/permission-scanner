// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

/**
 * @notice Base contract support for swaps
 */
abstract contract Swap {
    /**
     * @notice Internal swap function.  Override this function to add logic
     * before or after a swap.
     */
    function _swap(
        IMaverickV2Pool pool,
        address recipient,
        IMaverickV2Pool.SwapParams memory params,
        bytes memory data
    ) internal virtual returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut) = pool.swap(recipient, params, data);
    }
}
