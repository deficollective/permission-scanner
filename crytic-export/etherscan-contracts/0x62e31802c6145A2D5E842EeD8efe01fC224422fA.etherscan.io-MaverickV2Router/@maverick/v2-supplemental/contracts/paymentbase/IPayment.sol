// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPayableMulticall} from "@maverick/v2-common/contracts/base/IPayableMulticall.sol";

import {IState} from "./IState.sol";

interface IPayment is IPayableMulticall, IState {
    error PaymentSenderNotWETH9();
    error PaymentInsufficientBalance(address token, uint256 amountMinimum, uint256 contractBalance);

    receive() external payable;

    /**
     * @notice Unwrap WETH9 tokens into ETH and send that balance to recipient.
     * If less than amountMinimum WETH is avialble, then revert.
     */
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    /**
     * @notice Transfers specified token amount to recipient
     */
    function sweepTokenAmount(IERC20 token, uint256 amount, address recipient) external payable;

    /**
     * @notice Sweep entire ERC20 token balance on this contract to recipient.
     * If less than amountMinimum balance is avialble, then revert.
     */
    function sweepToken(IERC20 token, uint256 amountMinimum, address recipient) external payable;

    /**
     * @notice Send any ETH on this contract to msg.sender.
     */
    function refundETH() external payable;

    /**
     * @notice For tokenA and tokenB, sweep all of the
     * non-WETH tokens to msg.sender.  Any WETH balance is unwrapped to ETH and
     * then all the ETH on this contract is sent to msg.sender.
     */
    function unwrapAndSweep(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 tokenAAmountMin,
        uint256 tokenBAmountMin
    ) external payable;
}
