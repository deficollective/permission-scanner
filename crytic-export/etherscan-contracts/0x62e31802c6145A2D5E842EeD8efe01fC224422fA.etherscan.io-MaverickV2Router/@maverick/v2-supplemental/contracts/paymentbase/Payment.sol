// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TransferLib} from "@maverick/v2-common/contracts/libraries/TransferLib.sol";
import {PayableMulticall} from "@maverick/v2-common/contracts/base/PayableMulticall.sol";

import {IWETH9} from "./IWETH9.sol";
import {State} from "./State.sol";

import {IPayment} from "./IPayment.sol";

/**
 * @notice Payment helper function that lets user sweep ERC20 tokens off the
 * router and liquidity manager.  Also provides mechanism to wrap and unwrap
 * ETH/WETH so that it can be used in the Maverick pools.
 */
abstract contract Payment is State, PayableMulticall, IPayment {
    receive() external payable {
        if (IWETH9(msg.sender) != weth()) revert PaymentSenderNotWETH9();
    }

    /// @inheritdoc IPayment
    function unwrapWETH9(uint256 amountMinimum, address recipient) public payable {
        uint256 balanceWETH9 = weth().balanceOf(address(this));
        if (balanceWETH9 < amountMinimum)
            revert PaymentInsufficientBalance(address(weth()), amountMinimum, balanceWETH9);
        if (balanceWETH9 > 0) {
            weth().withdraw(balanceWETH9);
            Address.sendValue(payable(recipient), balanceWETH9);
        }
    }

    /// @inheritdoc IPayment
    function sweepToken(IERC20 token, uint256 amountMinimum, address recipient) public payable {
        uint256 balanceToken = token.balanceOf(address(this));
        if (balanceToken < amountMinimum)
            revert PaymentInsufficientBalance(address(token), amountMinimum, balanceToken);
        if (balanceToken > 0) {
            TransferLib.transfer(token, recipient, balanceToken);
        }
    }

    /// @inheritdoc IPayment
    function sweepTokenAmount(IERC20 token, uint256 amount, address recipient) public payable {
        TransferLib.transfer(token, recipient, amount);
    }

    /// @inheritdoc IPayment
    function unwrapAndSweep(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 tokenAAmountMin,
        uint256 tokenBAmountMin
    ) public payable {
        if (address(tokenA) == address(weth())) {
            unwrapWETH9(tokenAAmountMin, msg.sender);
            refundETH();
            sweepToken(tokenB, tokenBAmountMin, msg.sender);
        } else if (address(tokenB) == address(weth())) {
            sweepToken(tokenA, tokenAAmountMin, msg.sender);
            unwrapWETH9(tokenBAmountMin, msg.sender);
            refundETH();
        } else {
            sweepToken(tokenA, tokenAAmountMin, msg.sender);
            sweepToken(tokenB, tokenBAmountMin, msg.sender);
        }
    }

    /// @inheritdoc IPayment
    function refundETH() public payable {
        if (address(this).balance > 0) Address.sendValue(payable(msg.sender), address(this).balance);
    }

    /**
     * @notice Internal function to pay tokens or eth.
     * @param token ERC20 token to pay.
     * @param payer Address of the payer.
     * @param recipient Address of the recipient.
     * @param value Amount of tokens to pay.
     */
    function pay(IERC20 token, address payer, address recipient, uint256 value) internal {
        if (IWETH9(address(token)) == weth() && address(this).balance >= value) {
            weth().deposit{value: value}();
            weth().transfer(recipient, value);
        } else if (payer == address(this)) {
            TransferLib.transfer(token, recipient, value);
        } else {
            TransferLib.transferFrom(token, payer, recipient, value);
        }
    }
}
