// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IRouterErrors} from "./IRouterErrors.sol";

interface IExactOutputSlim is IRouterErrors {
    function exactOutputSingleMinimal(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountOut,
        int32 tickLimit
    ) external payable returns (uint256 amountIn, uint256 amountOut_);
}
