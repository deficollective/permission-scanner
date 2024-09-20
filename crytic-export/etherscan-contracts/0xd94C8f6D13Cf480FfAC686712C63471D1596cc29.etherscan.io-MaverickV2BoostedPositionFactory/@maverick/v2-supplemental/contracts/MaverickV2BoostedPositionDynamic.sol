// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransferLib} from "@maverick/v2-common/contracts/libraries/TransferLib.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {ONE} from "@maverick/v2-common/contracts/libraries/Constants.sol";

import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {BoostedPositionBase} from "./boostedpositionbase/BoostedPositionBase.sol";
import {PoolInspection} from "./libraries/PoolInspection.sol";

/**
 * @notice BoostedPosition for movement-mode Maverick V2 AMM liquidity
 * positions.  This contract inherits ERC20 and a given user's BP balance
 * represents their pro rata position in the boosted position.
 *
 * @dev Movement-mode bins can be merged in the V2 AMM.  Before any action can
 * be taken on this BP, the user must ensure that the underlying AMM bin
 * has not been merged.  If it has been merged, the user must first call
 * `migrateBinLiquidityToRoot`.
 */
contract MaverickV2BoostedPositionDynamic is IMaverickV2BoostedPosition, BoostedPositionBase {
    uint32 private _binId;
    uint256 private immutable _tokenAScale;
    uint256 private immutable _tokenBScale;

    /**
     * @dev Contructor does not do any validation of input paramters. This
     * contract is meant to be deployed by a deployer contract and that
     * contract does all of the paramter validations.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        IMaverickV2Pool pool_,
        uint8 kind_,
        uint32 binId_,
        uint256 tokenAScale_,
        uint256 tokenBScale_
    ) BoostedPositionBase(name_, symbol_, pool_, kind_, 1) {
        (_binId, _tokenAScale, _tokenBScale) = (binId_, tokenAScale_, tokenBScale_);
    }

    /**
     * @notice Checks to ensure bin is not merged.
     */
    modifier checkBinIsRoot() {
        if (pool.getBin(_binId).mergeId != 0) revert BoostedPositionMovementBinNotMigrated();
        _;
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function mint(address recipient) public checkBinIsRoot returns (uint256 deltaSupply) {
        uint32[] memory binIds_ = getBinIds();
        uint128[] memory ratios_ = getRatios();
        deltaSupply = _checkAndUpdateBinBalances(binIds_, ratios_);
        _mint(recipient, deltaSupply);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function burn(address recipient, uint256 amount) public returns (uint256 tokenAOut, uint256 tokenBOut) {
        migrateBinLiquidityToRoot();
        uint32[] memory binIds_ = getBinIds();
        uint128[] memory ratios_ = getRatios();
        (tokenAOut, tokenBOut) = _removeLiquidityAndUpdateBalances(amount, recipient, binIds_, ratios_);
        _burn(msg.sender, amount);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function migrateBinLiquidityToRoot() public {
        if (kind == 0) return;

        uint32 currentBinId = _binId;
        uint32 mergeId = pool.getBin(currentBinId).mergeId;
        if (mergeId == 0) return;

        /////////////////////
        // the BP bin has merged; need to move the BP liquidity to the new active bin
        /////////////////////

        // migrate first using max recursion.  If we run out of gas, need to
        // seperately and incrementally migrate liquidity through multiple
        // transactions before calling this function.  Any caller can
        // permissionlessly migrate bins by calling migrate directly on the
        // pool contract.
        pool.migrateBinUpStack(currentBinId, type(uint32).max);
        mergeId = pool.getBin(currentBinId).mergeId;

        uint32 newBinId = mergeId;

        // remove liquidity
        IMaverickV2Pool.RemoveLiquidityParams memory params = PoolInspection.maxRemoveParams(
            pool,
            currentBinId,
            address(this),
            SUBACCOUNT
        );
        (uint256 tokenAAmount, uint256 tokenBAmount) = pool.removeLiquidity(address(this), SUBACCOUNT, params);

        if (tokenAAmount != 0 || tokenBAmount != 0) {
            IMaverickV2Pool.AddLiquidityParams memory addParams = PoolInspection.lpBalanceForTargetReserveAmounts(
                pool,
                newBinId,
                tokenAAmount,
                tokenBAmount,
                _tokenAScale,
                _tokenBScale
            );
            pool.addLiquidity(address(this), SUBACCOUNT, addParams, bytes(""));
        }

        // _binId changed; update it
        _binId = newBinId;
        uint128 newBinBalance = pool.balanceOf(address(this), SUBACCOUNT, newBinId);
        binBalances[0] = newBinBalance;

        emit BoostedPositionMigrateBinLiquidity(currentBinId, newBinId, newBinBalance);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getRatios() public pure returns (uint128[] memory ratios_) {
        ratios_ = new uint128[](1);
        ratios_[0] = ONE;
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getBinIds() public view checkBinIsRoot returns (uint32[] memory binIds_) {
        return getRawBinIds();
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getRawBinIds() public view returns (uint32[] memory binIds_) {
        binIds_ = new uint32[](1);
        binIds_[0] = _binId;
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function skim(address) public pure returns (uint256 tokenAOut, uint256 tokenBOut) {
        // no need to skim since this is only one bin; instead just mint
        return (0, 0);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function skimmableAmount() public pure returns (uint128 amount) {
        return 0;
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getTicks() public view checkBinIsRoot returns (int32[] memory ticks) {
        ticks = new int32[](1);
        ticks[0] = pool.getBin(_binId).tick;
    }

    function maverickV2AddLiquidityCallback(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amountA,
        uint256 amountB,
        bytes calldata
    ) external {
        // no permission needed as this contract does not hold assets unless we
        // are migrating liquidity; for dust leftover after migration, this
        // function can be used for sweeping the tokens off the contract.
        if (amountA != 0) {
            TransferLib.transfer(tokenA, address(pool), amountA);
        }
        if (amountB != 0) {
            TransferLib.transfer(tokenB, address(pool), amountB);
        }
    }
}
