// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {IMaverickV2BoostedPositionLens} from "./interfaces/IMaverickV2BoostedPositionLens.sol";
import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {PoolInspection} from "./libraries/PoolInspection.sol";

/**
 * @notice BoostedPosition Lens contract that provides the underlying reserves
 * related to BPs.
 */
contract MaverickV2BoostedPositionLens is IMaverickV2BoostedPositionLens {
    uint256 private constant BP_SUBACCOUNT = 0;

    /// @inheritdoc IMaverickV2BoostedPositionLens
    function boostedPositionInformation(
        IMaverickV2BoostedPosition bp
    ) public view returns (BoostedPositionInformation memory info) {
        info.pool = bp.pool();
        info.tokenA = info.pool.tokenA();
        info.tokenB = info.pool.tokenB();
        info.kind = bp.kind();
        info.binBalances = bp.getBinBalances();
        info.binIds = bp.getRawBinIds();
        (, , info.binAAmounts, info.binBAmounts, info.ticks, ) = PoolInspection.subaccountPositionInformation(
            info.pool,
            address(bp),
            BP_SUBACCOUNT,
            info.binIds
        );

        _adjustAmounts(bp, info);
    }

    /// @inheritdoc IMaverickV2BoostedPositionLens
    function boostedPositionUserInformation(
        IMaverickV2BoostedPosition bp,
        address user
    ) external view returns (BoostedPositionInformation memory info, uint256 userAmountA, uint256 userAmountB) {
        info = boostedPositionInformation(bp);
        uint256 userBpBalance = bp.balanceOf(user);
        uint256 bpTotalSupply = bp.totalSupply();
        userAmountA = Math.mulDivFloor(info.amountA, userBpBalance, bpTotalSupply);
        userAmountB = Math.mulDivFloor(info.amountB, userBpBalance, bpTotalSupply);
    }

    /**
     * @notice Adjust BP information to pro rate by amount of bin balance that
     * has been attributed to the BP mint.
     */
    function _adjustAmounts(IMaverickV2BoostedPosition bp, BoostedPositionInformation memory info) internal view {
        for (uint256 i = 0; i < info.binIds.length; i++) {
            uint256 binLpBalance = info.pool.balanceOf(address(bp), BP_SUBACCOUNT, info.binIds[i]);
            // pro rate bin amount by internal BP accounting of balance amount
            // accounted_bp_reserve = full_bp_reserve * accounted_bp_lp_balance / full_lp_balance
            info.binAAmounts[i] = Math.mulDivFloor(info.binAAmounts[i], info.binBalances[i], binLpBalance);
            info.amountA += info.binAAmounts[i];

            info.binBAmounts[i] = Math.mulDivFloor(info.binBAmounts[i], info.binBalances[i], binLpBalance);
            info.amountB += info.binBAmounts[i];
        }
    }
}
