// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {ICallbackOperations} from "./ICallbackOperations.sol";
import {Path} from "../libraries/Path.sol";
import {ExactOutputSlim} from "./ExactOutputSlim.sol";

abstract contract CallbackOperations is ExactOutputSlim, ICallbackOperations {
    using Path for bytes;

    struct CallbackData {
        bytes path;
        address payer;
    }

    uint256 private __amountIn = type(uint256).max;

    /// @inheritdoc ICallbackOperations
    function exactOutputSingle(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        uint256 amountInMaximum
    ) public payable returns (uint256 amountIn, uint256 amountOut_) {
        int32 tickLimit = tokenAIn ? type(int32).max : type(int32).min;
        (amountIn, amountOut_) = _exactOutputSingleWithTickCheck(pool, recipient, amountOut, tokenAIn, tickLimit);
        if (amountIn > amountInMaximum) revert RouterTooMuchRequested(amountInMaximum, amountIn);
    }

    /// @inheritdoc ICallbackOperations
    function outputSingleWithTickLimit(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        int32 tickLimit,
        uint256 amountInMaximum,
        uint256 amountOutMinimum
    ) public payable returns (uint256 amountIn_, uint256 amountOut_) {
        (amountIn_, amountOut_) = _exactOutputSingleWithTickCheck(pool, recipient, amountOut, tokenAIn, tickLimit);
        if (amountIn_ > amountInMaximum) revert RouterTooMuchRequested(amountInMaximum, amountIn_);
        if (amountOut_ < amountOutMinimum) revert RouterTooLittleReceived(amountOutMinimum, amountOut_);
    }

    /// @inheritdoc ICallbackOperations
    function exactOutputMultiHop(
        address recipient,
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum
    ) public payable returns (uint256 amountIn) {
        // recursively swap through the hops starting with the ouput pool.
        // inside of the swap callback, this contract will call the next pool
        // in the path until it gets to the input pool of the path.
        _exactOutputInternal(amountOut, recipient, CallbackData({path: path, payer: msg.sender}));
        amountIn = __amountIn;
        if (amountIn > amountInMaximum) revert RouterTooMuchRequested(amountInMaximum, amountIn);
        __amountIn = type(uint256).max;
    }

    /// @inheritdoc ICallbackOperations
    function inputSingleWithTickLimit(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountIn,
        int32 tickLimit,
        uint256 amountOutMinimum
    ) public payable returns (uint256 amountIn_, uint256 amountOut) {
        // swap
        IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
            amount: amountIn,
            tokenAIn: tokenAIn,
            exactOutput: false,
            tickLimit: tickLimit
        });
        (amountIn_, amountOut) = _swap(pool, recipient, swapParams, abi.encode(msg.sender));
        if (amountOut < amountOutMinimum) revert RouterTooLittleReceived(amountOutMinimum, amountOut);
    }

    function _exactOutputInternal(
        uint256 amountOut,
        address recipient,
        CallbackData memory data
    ) internal returns (uint256 amountIn) {
        if (recipient == address(0)) recipient = address(this);
        (IMaverickV2Pool pool, bool tokenAIn) = data.path.decodeFirstPool();

        int32 tickLimit = tokenAIn ? type(int32).max : type(int32).min;
        IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
            amount: amountOut,
            tokenAIn: tokenAIn,
            exactOutput: true,
            tickLimit: tickLimit
        });

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = _swap(pool, recipient, swapParams, abi.encode(data));
    }

    function maverickV2SwapCallback(
        IERC20 tokenIn,
        uint256 amountToPay,
        uint256,
        bytes calldata _data
    ) external override {
        // only used for either single-hop exactinput calls with a tick limit,
        // or exactouput calls.  if the path has more than one pool, then this
        // is an exactouput multihop swap.
        if (amountToPay == 0) revert RouterZeroSwap();
        if (!factory().isFactoryPool(IMaverickV2Pool(msg.sender))) revert RouterNotFactoryPool();

        if (_data.length == 32) {
            // exact in
            address payer = abi.decode(_data, (address));
            pay(tokenIn, payer, msg.sender, amountToPay);
        } else {
            // exact out
            CallbackData memory data = abi.decode(_data, (CallbackData));

            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
                _exactOutputInternal(amountToPay, msg.sender, data);
            } else {
                // must be at first/input pool
                __amountIn = amountToPay;
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }
}
