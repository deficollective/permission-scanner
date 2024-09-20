// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {Payment} from "../paymentbase/Payment.sol";
import {IExactOutputSlim} from "./IExactOutputSlim.sol";
import {Swap} from "./Swap.sol";

abstract contract ExactOutputSlim is Payment, Swap, IExactOutputSlim {
    /**
     * @dev Callback function called by Maverick V2 pools when swapping tokens.
     * @param tokenIn The input token.
     * @param amountToPay The amount to pay.
     * @param data Additional data.
     */
    function maverickV2SwapCallback(
        IERC20 tokenIn,
        uint256 amountToPay,
        uint256,
        bytes calldata data
    ) external virtual {
        if (!factory().isFactoryPool(IMaverickV2Pool(msg.sender))) revert RouterNotFactoryPool();
        address payer = abi.decode(data, (address));
        if (amountToPay != 0) pay(tokenIn, payer, msg.sender, amountToPay);
    }

    /**
     * @dev Perform a swap with an exact output amount.
     * @param recipient The recipient of the swapped tokens.
     * @param pool The MaverickV2 pool to use for the swap.
     * @param tokenAIn Whether token A is the input token.
     * @param amountOut The exact output amount.
     * @param tickLimit The tick limit for the swap.
     * @return amountIn The input amount required to achieve the exact output.
     * @return amountOut_ The actual output amount received from the swap.
     */
    function exactOutputSingleMinimal(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        int32 tickLimit
    ) public payable returns (uint256 amountIn, uint256 amountOut_) {
        (amountIn, amountOut_) = _exactOutputSingleWithTickCheck(pool, recipient, amountOut, tokenAIn, tickLimit);
    }

    /**
     * @dev Perform an exact output single swap with tick limit validation.
     * @param pool The MaverickV2 pool to use for the swap.
     * @param recipient The recipient of the swapped tokens.
     * @param amountOut The exact output amount.
     * @param tokenAIn Whether token A is the input token.
     * @param tickLimit The tick limit for the swap.
     * @return amountIn The input amount required to achieve the exact output.
     * @return _amountOut The actual output amount received from the swap.
     */
    function _exactOutputSingleWithTickCheck(
        IMaverickV2Pool pool,
        address recipient,
        uint256 amountOut,
        bool tokenAIn,
        int32 tickLimit
    ) internal returns (uint256 amountIn, uint256 _amountOut) {
        IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
            amount: amountOut,
            tokenAIn: tokenAIn,
            exactOutput: true,
            tickLimit: tickLimit
        });
        (amountIn, _amountOut) = _swap(
            pool,
            (recipient == address(0)) ? address(this) : recipient,
            swapParams,
            abi.encode(msg.sender)
        );
    }
}
