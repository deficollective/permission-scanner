// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {Multicall} from "@maverick/v2-common/contracts/base/Multicall.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {IBoostedPositionBase} from "./IBoostedPositionBase.sol";
import {IMaverickV2BoostedPosition} from "../interfaces/IMaverickV2BoostedPosition.sol";
import {Checks} from "../base/Checks.sol";

/**
 * @notice Base BP contract functions.
 */
abstract contract BoostedPositionBase is ERC20, Multicall, Checks, ReentrancyGuard, IBoostedPositionBase {
    using Cast for uint256;

    /// @inheritdoc IBoostedPositionBase
    IMaverickV2Pool public immutable pool;

    /// @inheritdoc IBoostedPositionBase
    uint8 public immutable kind;

    /// @inheritdoc IBoostedPositionBase
    uint8 public immutable binCount;

    /// @inheritdoc IBoostedPositionBase
    uint128[] public binBalances;

    uint256 internal constant SUBACCOUNT = 0;

    constructor(
        string memory name_,
        string memory symbol_,
        IMaverickV2Pool pool_,
        uint8 kind_,
        uint8 binCount_
    ) ERC20(name_, symbol_) {
        (pool, kind, binCount) = (pool_, kind_, binCount_);
        binBalances = new uint128[](binCount_);
    }

    /// @inheritdoc IBoostedPositionBase
    function getBinBalances() public view returns (uint128[] memory binBalances_) {
        binBalances_ = binBalances;
    }

    function _skimmableAmount(uint32 binId) internal view returns (uint128 amount) {
        uint128 trueBalance = pool.balanceOf(address(this), SUBACCOUNT, binId);
        amount = trueBalance - binBalances[0];
    }

    function _skim(
        address recipient,
        uint32 binId
    ) internal nonReentrant returns (uint256 tokenAOut, uint256 tokenBOut) {
        uint32[] memory binIds_ = new uint32[](1);
        uint128[] memory amounts = new uint128[](1);
        amounts[0] = _skimmableAmount(binId);

        if (amounts[0] != 0) {
            binIds_[0] = binId;
            IMaverickV2Pool.RemoveLiquidityParams memory params = IMaverickV2Pool.RemoveLiquidityParams({
                binIds: binIds_,
                amounts: amounts
            });

            (tokenAOut, tokenBOut) = pool.removeLiquidity(recipient, SUBACCOUNT, params);
        }
    }

    function _removeLiquidityAndUpdateBalances(
        uint256 amount,
        address recipient,
        uint32[] memory binIds_,
        uint128[] memory ratios_
    ) internal nonReentrant returns (uint256 tokenAOut, uint256 tokenBOut) {
        unchecked {
            uint128[] memory binBalances_ = binBalances;
            uint128[] memory newBinBalances = new uint128[](binIds_.length);
            uint128[] memory diffs = new uint128[](binIds_.length);
            uint256 totalSupply_ = totalSupply();

            for (uint256 i = 0; i < binIds_.length; i++) {
                diffs[i] = i == 0
                    ? Math.mulDivFloor(amount, binBalances_[i], totalSupply_).toUint128()
                    : Math.min128(binBalances_[i], Math.mulFloor(diffs[0], ratios_[i]).toUint128());
                newBinBalances[i] = binBalances_[i] - diffs[i];
            }

            binBalances = newBinBalances;

            IMaverickV2Pool.RemoveLiquidityParams memory params = IMaverickV2Pool.RemoveLiquidityParams({
                binIds: binIds_,
                amounts: diffs
            });

            (tokenAOut, tokenBOut) = pool.removeLiquidity(recipient, SUBACCOUNT, params);
        }
    }

    function _checkAndUpdateBinBalances(
        uint32[] memory binIds_,
        uint128[] memory ratios_
    ) internal nonReentrant returns (uint128 deltaSupply) {
        uint128[] memory binBalances_ = binBalances;
        uint128[] memory newBinBalances = new uint128[](binIds_.length);
        uint256 totalSupply_ = totalSupply();

        uint128 trueBalance = pool.balanceOf(address(this), SUBACCOUNT, binIds_[0]);
        uint128 diff0 = trueBalance - binBalances_[0];
        newBinBalances[0] = trueBalance;
        for (uint256 i = 1; i < binIds_.length; i++) {
            trueBalance = pool.balanceOf(address(this), SUBACCOUNT, binIds_[i]);
            uint128 thisDiff = trueBalance - binBalances_[i];
            uint128 required = Math.mulCeil(diff0, ratios_[i]).toUint128();
            if (required > thisDiff)
                revert IMaverickV2BoostedPosition.BoostedPositionTooLittleLiquidityAdded(
                    i,
                    binIds_[i],
                    required,
                    thisDiff
                );
            newBinBalances[i] = binBalances_[i] + required;
        }

        binBalances = newBinBalances;
        deltaSupply = totalSupply_ == 0 ? diff0 : Math.mulDivFloor(diff0, totalSupply_, binBalances_[0]).toUint128();
    }
}
