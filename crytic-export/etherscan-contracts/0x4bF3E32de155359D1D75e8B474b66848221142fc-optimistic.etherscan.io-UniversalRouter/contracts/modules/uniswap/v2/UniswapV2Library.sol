// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IPool} from 'contracts/interfaces/external/IPool.sol';
import {IPoolFactory} from 'contracts/interfaces/external/IPoolFactory.sol';

import {Route} from '../../../base/RouterImmutables.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title Uniswap v2 Helper Library
/// @notice Calculates the recipient address for a command
library UniswapV2Library {
    error InvalidReserves();
    error InvalidPath();
    error StableExactOutputUnsupported();

    /// @notice Calculates the v2 address for a pair without making any external calls
    /// @param factory The address of the v2 pool factory
    /// @param implementation The address of the implementation of the v2 pool
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @param stable Whether pair is stable or volatile
    /// @return pair The resultant v2 pair address
    function pairFor(address factory, address implementation, address tokenA, address tokenB, bool stable)
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, implementation, token0, token1, stable);
    }

    /// @notice Calculates the v2 address for a pair and the pair's token0
    /// @param factory The address of the v2 pool factory
    /// @param implementation The address of the implementation of the v2 pool
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @param stable Whether pair is stable or volatile
    /// @return pair The resultant v2 pair address
    /// @return token0 The token considered token0 in this pair
    function pairAndToken0For(address factory, address implementation, address tokenA, address tokenB, bool stable)
        internal
        pure
        returns (address pair, address token0)
    {
        address token1;
        (token0, token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, implementation, token0, token1, stable);
    }

    /// @notice Calculates the v2 address for a pair assuming the input tokens are pre-sorted
    /// @param factory The address of the v2 pool factory
    /// @param implementation The address of the implementation of the v2 pool
    /// @param token0 The pair's token0
    /// @param token1 The pair's token1
    /// @param stable Whether pair is stable or volatile
    /// @return pair The resultant v2 pair address
    function pairForPreSorted(address factory, address implementation, address token0, address token1, bool stable)
        private
        pure
        returns (address pair)
    {
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        pair = Clones.predictDeterministicAddress({implementation: implementation, salt: salt, deployer: factory});
    }

    /// @notice Calculates the v2 address for a pair and fetches the reserves for each token
    /// @param factory The address of the v2 pool factory
    /// @param implementation The address of the implementation of the v2 pool
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @param stable Whether pair is stable or volatile
    /// @return pair The resultant v2 pair address
    /// @return reserveA The reserves for tokenA
    /// @return reserveB The reserves for tokenB
    function pairAndReservesFor(address factory, address implementation, address tokenA, address tokenB, bool stable)
        private
        view
        returns (address pair, uint256 reserveA, uint256 reserveB)
    {
        address token0;
        (pair, token0) = pairAndToken0For(factory, implementation, tokenA, tokenB, stable);
        (uint256 reserve0, uint256 reserve1,) = IPool(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice Given an input asset amount returns the maximum output amount of the other asset
    /// @param factory The address of the v2 pool factory
    /// @param pair The pair to get amount in from
    /// @param amountIn The token input amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @param route Route to get amount out for
    /// @return amountOut The output amount of the output token
    function getAmountOut(
        address factory,
        address pair,
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        Route memory route
    ) internal view returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        // adapted from _getAmountOut in Pool.sol
        amountIn -= (amountIn * IPoolFactory(factory).getFee(pair, route.stable)) / 10_000;
        if (route.stable) {
            uint256 decimalsIn = 10 ** ERC20(route.from).decimals();
            uint256 decimalsOut = 10 ** ERC20(route.to).decimals();
            uint256 normalizedReserveIn = reserveIn * 1e18 / decimalsIn;
            uint256 normalizedReserveOut = reserveOut * 1e18 / decimalsOut;
            uint256 normalizedAmountIn = amountIn * 1e18 / decimalsIn;
            uint256 xy = _k(normalizedReserveIn, normalizedReserveOut);
            uint256 y = normalizedReserveOut - getY(normalizedAmountIn + normalizedReserveIn, xy, normalizedReserveOut);
            return (y * decimalsOut) / 1e18;
        } else {
            amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        }
    }

    /// @notice Returns the input amount needed for a desired output amount in a single-hop trade
    /// @param factory The address of the v2 pool factory
    /// @param pair The pair to get amount in from
    /// @param amountOut The desired output amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @param route Route to get amount in for
    /// @return amountIn The input amount of the input token
    function getAmountIn(
        address factory,
        address pair,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        Route memory route
    ) internal view returns (uint256 amountIn) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        if (!route.stable) {
            uint256 fee = IPoolFactory(factory).getFee(pair, route.stable);
            amountIn = (amountOut * reserveIn) / (reserveOut - amountOut);
            amountIn = amountIn * 10_000 / (10_000 - fee) + 1;
        } else {
            revert StableExactOutputUnsupported();
        }
    }

    /// @notice Returns the input amount needed for a desired output amount in a multi-hop trade
    /// @param factory The address of the v2 pool factory
    /// @param implementation The address of the implementation of the v2 pool
    /// @param amountOut The desired output amount
    /// @param routes The routes of the multi-hop trade
    /// @return amount The input amount of the input token
    /// @return pair The first pair in the trade
    function getAmountInMultihop(address factory, address implementation, uint256 amountOut, Route[] memory routes)
        internal
        view
        returns (uint256 amount, address pair)
    {
        if (routes.length == 0) revert InvalidPath();
        amount = amountOut;
        for (uint256 i = routes.length; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) =
                pairAndReservesFor(factory, implementation, routes[i - 1].from, routes[i - 1].to, routes[i - 1].stable);
            amount = getAmountIn(factory, pair, amount, reserveIn, reserveOut, routes[i - 1]);
        }
    }

    /// @notice Sorts two tokens to return token0 and token1
    /// @param tokenA The first token to sort
    /// @param tokenB The other token to sort
    /// @return token0 The smaller token by address value
    /// @return token1 The larger token by address value
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Calculates k based on stable AMM formula given normalized reserves
    function _k(uint256 normalizedReservesA, uint256 normalizedReservesB) internal pure returns (uint256) {
        uint256 _a = (normalizedReservesA * normalizedReservesB) / 1e18;
        uint256 _b =
            ((normalizedReservesA * normalizedReservesA) / 1e18 + (normalizedReservesB * normalizedReservesB) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        uint256 _a = (x0 * y) / 1e18;
        uint256 _b = ((x0 * x0) / 1e18 + (y * y) / 1e18);
        return (_a * _b) / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function getY(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 k = _f(x0, y);
            if (k < xy) {
                // there are two cases where dy == 0
                // case 1: The y is converged and we find the correct answer
                // case 2: _d(x0, y) is too large compare to (xy - k) and the rounding error
                //         screwed us.
                //         In this case, we need to increase y by 1
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy) {
                        // We found the correct answer. Return y
                        return y;
                    }
                    if (_k(x0, y + 1) > xy) {
                        // If k(x0, y + 1) > xy, then we are close to the correct answer.
                        // There's no closer answer than y + 1
                        return y + 1;
                    }
                    dy = 1;
                }
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                if (dy == 0) {
                    if (k == xy || _f(x0, y - 1) < xy) {
                        // Likewise, if k == xy, we found the correct answer.
                        // If _f(x0, y - 1) < xy, then we are close to the correct answer.
                        // There's no closer answer than "y"
                        // It's worth mentioning that we need to find y where f(x0, y) >= xy
                        // As a result, we can't return y - 1 even it's closer to the correct answer
                        return y;
                    }
                    dy = 1;
                }
                y = y - dy;
            }
        }
        revert('!y');
    }
}
