// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {PackLib} from "../libraries/PackLib.sol";
import {Payment} from "../paymentbase/Payment.sol";
import {Path} from "../libraries/Path.sol";
import {IPushOperations} from "./IPushOperations.sol";
import {Swap} from "./Swap.sol";

/**
 * @notice Exactinput router operations that can be performed by pushing assets
 * to the pool to swap.
 */
abstract contract PushOperations is Payment, Swap, IPushOperations {
    using Path for bytes;

    /// @inheritdoc IPushOperations
    function exactInputSinglePackedArgs(bytes memory argsPacked) public payable returns (uint256 amountOut) {
        (address recipient, IMaverickV2Pool pool, bool tokenAIn, uint256 amountIn, uint256 amountOutMinimum) = PackLib
            .unpackExactInputSingleArgsAmounts(argsPacked);
        return exactInputSingle(recipient, pool, tokenAIn, amountIn, amountOutMinimum);
    }

    /// @inheritdoc IPushOperations
    function exactInputSingle(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) public payable returns (uint256 amountOut) {
        // pay pool
        pay(tokenAIn ? pool.tokenA() : pool.tokenB(), msg.sender, address(pool), amountIn);

        // swap
        IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
            amount: amountIn,
            tokenAIn: tokenAIn,
            exactOutput: false,
            tickLimit: tokenAIn ? type(int32).max : type(int32).min
        });
        (, amountOut) = _swap(pool, recipient, swapParams, bytes(""));

        // check slippage
        if (amountOut < amountOutMinimum) revert RouterTooLittleReceived(amountOutMinimum, amountOut);
    }

    /// @inheritdoc IPushOperations
    function exactInputMultiHop(
        address recipient,
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) public payable returns (uint256 amountOut) {
        (IMaverickV2Pool pool, bool tokenAIn) = path.decodeFirstPool();

        // pay first pool
        pay(tokenAIn ? pool.tokenA() : pool.tokenB(), msg.sender, address(pool), amountIn);

        amountOut = amountIn;
        while (true) {
            // if we have more pools, pay next pool, if not, pay recipient
            bool stillMultiPoolSwap = path.hasMultiplePools();
            address nextRecipient = stillMultiPoolSwap ? path.decodeNextPoolAddress() : recipient;

            // do swap and send proceeds to nextRecipient
            IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
                amount: amountOut,
                tokenAIn: tokenAIn,
                exactOutput: false,
                tickLimit: tokenAIn ? type(int32).max : type(int32).min
            });
            (, amountOut) = _swap(pool, nextRecipient, swapParams, bytes(""));

            // if there is more path, loop, if not, break
            if (stillMultiPoolSwap) {
                path = path.skipToken();
                (pool, tokenAIn) = path.decodeFirstPool();
            } else {
                break;
            }
        }
        if (amountOut < amountOutMinimum) revert RouterTooLittleReceived(amountOutMinimum, amountOut);
    }
}
