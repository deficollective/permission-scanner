// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {ImmutableArrayGetter} from "./boostedpositionbase/ImmutableArrayGetter.sol";
import {BoostedPositionBase} from "./boostedpositionbase/BoostedPositionBase.sol";

/**
 * @notice BoostedPosition for static-mode Maverick V2 AMM liquidity
 * positions.  This contract inherits ERC20 and a given user's BP balance
 * represents their pro rata position in the boosted position.
 */
contract MaverickV2BoostedPositionStatic is ImmutableArrayGetter, IMaverickV2BoostedPosition, BoostedPositionBase {
    /**
     * @notice Constructor does not do any validation of input parameters. This
     * contract is meant to be deployed by a factory contract and that
     * factory contract should perform parameter validations.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        IMaverickV2Pool pool_,
        uint8 binCount_,
        bytes32[3] memory binData,
        bytes32[12] memory ratioData
    ) BoostedPositionBase(name_, symbol_, pool_, 0, binCount_) ImmutableArrayGetter(binCount_, binData, ratioData) {}

    /// @inheritdoc IMaverickV2BoostedPosition
    function mint(address recipient) public returns (uint256 deltaSupply) {
        uint32[] memory binIds_ = getBinIds();
        uint128[] memory ratios_ = getRatios();
        deltaSupply = _checkAndUpdateBinBalances(binIds_, ratios_);
        _mint(recipient, deltaSupply);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function burn(address recipient, uint256 amount) public returns (uint256 tokenAOut, uint256 tokenBOut) {
        uint32[] memory binIds_ = getBinIds();
        uint128[] memory ratios_ = getRatios();
        (tokenAOut, tokenBOut) = _removeLiquidityAndUpdateBalances(amount, recipient, binIds_, ratios_);
        // ERC20 contract _burn checks to ensure user has at least amount
        _burn(msg.sender, amount);
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function migrateBinLiquidityToRoot() public pure {
        return;
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getTicks() public view returns (int32[] memory ticks) {
        ticks = new int32[](binCount);
        for (uint8 k; k < binCount; k++) {
            ticks[k] = pool.getBin(_getBinId(k)).tick;
        }
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getBinIds() public view returns (uint32[] memory) {
        return _getBinIds();
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getRawBinIds() public view returns (uint32[] memory) {
        return _getBinIds();
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function getRatios() public view returns (uint128[] memory) {
        return _getRatios();
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function skim(address recipient) public returns (uint256 tokenAOut, uint256 tokenBOut) {
        if (binCount == 1) return (0, 0);
        return _skim(recipient, _getBinId(0));
    }

    /// @inheritdoc IMaverickV2BoostedPosition
    function skimmableAmount() public view returns (uint128 amount) {
        if (binCount == 1) return 0;
        return _skimmableAmount(_getBinId(0));
    }
}
