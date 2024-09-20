// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IMaverickV2BoostedPosition} from "./IMaverickV2BoostedPosition.sol";

interface IMaverickV2BoostedPositionLens {
    struct BoostedPositionInformation {
        IMaverickV2Pool pool;
        IERC20 tokenA;
        IERC20 tokenB;
        uint8 kind;
        uint128[] binBalances;
        uint32[] binIds;
        int32[] ticks;
        uint256 amountA;
        uint256 amountB;
        uint256[] binAAmounts;
        uint256[] binBAmounts;
    }

    /**
     * @notice Return BP information.
     */
    function boostedPositionInformation(
        IMaverickV2BoostedPosition bp
    ) external view returns (BoostedPositionInformation memory info);

    /**
     * @notice Return BP information and user reserves.
     */
    function boostedPositionUserInformation(
        IMaverickV2BoostedPosition bp,
        address user
    ) external view returns (BoostedPositionInformation memory info, uint256 userAmountA, uint256 userAmountB);
}
