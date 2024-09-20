// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IBoostedPositionBase} from "../boostedpositionbase/IBoostedPositionBase.sol";

interface IMaverickV2BoostedPosition is IBoostedPositionBase {
    event BoostedPositionMigrateBinLiquidity(uint32 currentBinId, uint32 newBinId, uint128 newBinBalance);

    error BoostedPositionTooLittleLiquidityAdded(uint256 binIdIndex, uint32 binId, uint128 required, uint128 available);
    error BoostedPositionMovementBinNotMigrated();

    /**
     * @notice Mints BP LP position to recipient.  User has to add liquidity to
     * BP contract before making this call as this mint function simply assigns
     * any new liquidity that this BP possesses in the pool to the recipient.
     * Accordingly, this function should only be called in the same transaction
     * where liquidity has been added to a pool as part of a multicall or
     * through a router/manager contract.
     */
    function mint(address recipient) external returns (uint256 deltaSupply);

    /**
     * @notice Burns BP LP positions and redeems the underlying A/B token to the recipient.
     */
    function burn(address recipient, uint256 amount) external returns (uint256 tokenAOut, uint256 tokenBOut);

    /**
     * @notice Migrates all underlying movement-mode liquidity from a merged
     * bin to the active parent of the merged bin.  For Static BPs, this
     * function is a no-op and never needs to be called.
     */
    function migrateBinLiquidityToRoot() external;

    /**
     * @notice Array of ticks where the underlying BP liquidity exists.
     */
    function getTicks() external view returns (int32[] memory ticks);

    /**
     * @notice Array of relative pool bin LP balance of the bins in the BP.
     */
    function getRatios() external view returns (uint128[] memory ratios_);

    /**
     * @notice Array of BP binIds.  Will revert if the BP is a movement mode
     * and the underlying bin is merged.
     */
    function getBinIds() external view returns (uint32[] memory binIds_);

    /**
     * @notice Array of BP binIds.  Will not revert if the BP is a movement mode
     * and the underlying bin is merged.  For statis BPs, this returns the same
     * value as `getBinIds`.
     */
    function getRawBinIds() external view returns (uint32[] memory);

    /**
     * @notice Removes excess liquidity from the binId[0] bin and sends to
     * recipient. Skimming is desirable if there is more than one bin in the BP
     * and the skimmable amount is non-zero.
     * Skimming amount is only applicable if the number of bins is more than
     * one.  For single-bin BPs, a user can effectively "skim" by minting BP
     * tokens to themselves.
     */
    function skim(address recipient) external returns (uint256 tokenAOut, uint256 tokenBOut);

    /**
     * @notice Returns the amount of binIds[0] LP balance that is skimmable in
     * the BP.  If this number is non-zero, it is desirable to skim before
     * minting to ensure that the ratio solvency checks pass.  Checking the
     * skimmable amount is only applicable if the number of bins is more than
     * one.  For single-bin BPs, a user can effectively "skim" by minting BP
     * tokens to themselves.
     */
    function skimmableAmount() external view returns (uint128 amount);
}
