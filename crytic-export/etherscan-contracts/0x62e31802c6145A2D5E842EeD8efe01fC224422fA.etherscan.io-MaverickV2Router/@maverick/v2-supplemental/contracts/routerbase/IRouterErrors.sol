// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

interface IRouterErrors {
    error RouterZeroSwap();
    error RouterNotFactoryPool();
    error RouterTooLittleReceived(uint256 amountOutMinimum, uint256 amountOut);
    error RouterTooMuchRequested(uint256 amountInMaximum, uint256 amountIn);
}
