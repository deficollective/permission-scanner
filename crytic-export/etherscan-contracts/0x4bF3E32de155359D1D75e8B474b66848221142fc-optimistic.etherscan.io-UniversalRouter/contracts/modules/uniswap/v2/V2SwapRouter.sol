// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IPool} from 'contracts/interfaces/external/IPool.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {RouterImmutables, Route} from '../../../base/RouterImmutables.sol';
import {Payments} from '../../Payments.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title Router for Uniswap v2 Trades
abstract contract V2SwapRouter is RouterImmutables, Permit2Payments {
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    function _v2Swap(Route[] memory routes, address recipient, address pair) private {
        unchecked {
            uint256 length = routes.length;
            if (length == 0) revert V2InvalidPath();

            // cached to save on duplicate operations
            (address token0,) = UniswapV2Library.sortTokens(routes[0].from, routes[0].to);
            uint256 finalPairIndex = length - 1;
            for (uint256 i; i < length; i++) {
                (address input) = (routes[i].from);
                (uint256 reserve0, uint256 reserve1,) = IPool(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniswapV2Library.getAmountOut(
                    UNISWAP_V2_FACTORY, pair, amountInput, reserveInput, reserveOutput, routes[i]
                );
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < finalPairIndex
                    ? UniswapV2Library.pairAndToken0For(
                        UNISWAP_V2_FACTORY,
                        UNISWAP_V2_IMPLEMENTATION,
                        routes[i + 1].from,
                        routes[i + 1].to,
                        routes[i + 1].stable
                    )
                    : (recipient, address(0));
                IPool(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a Uniswap v2 exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param routes The routes of the trade as an array of Route structs
    /// @param payer The address that will be paying the input
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        Route[] memory routes,
        address payer
    ) internal {
        address firstPair = UniswapV2Library.pairFor(
            UNISWAP_V2_FACTORY, UNISWAP_V2_IMPLEMENTATION, routes[0].from, routes[0].to, routes[0].stable
        );
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(routes[0].from, payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(routes[routes.length - 1].to);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(routes, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice Performs a Uniswap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param routes The routes of the trade as an array of Route structs
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        Route[] memory routes,
        address payer
    ) internal {
        (uint256 amountIn, address firstPair) =
            UniswapV2Library.getAmountInMultihop(UNISWAP_V2_FACTORY, UNISWAP_V2_IMPLEMENTATION, amountOut, routes);
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer(routes[0].from, payer, firstPair, amountIn);
        _v2Swap(routes, recipient, firstPair);
    }
}
