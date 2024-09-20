// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IRewardAccounting} from "./IRewardAccounting.sol";

/**
 * @notice Provides ERC20-like functions for minting, burning, balance tracking
 * and total supply.  Tracking is based on a tokenId user index instead of an
 * address.
 */
abstract contract RewardAccounting is IRewardAccounting {
    mapping(uint256 account => uint256) private _stakeBalances;

    uint256 private _stakeTotalSupply;

    /// @inheritdoc IRewardAccounting
    function stakeBalanceOf(uint256 tokenId) public view returns (uint256 balance) {
        balance = _stakeBalances[tokenId];
    }

    /// @inheritdoc IRewardAccounting
    function stakeTotalSupply() public view returns (uint256 supply) {
        supply = _stakeTotalSupply;
    }

    /**
     * @notice Mint to staking account for a tokenId account.
     */
    function _mintStake(uint256 tokenId, uint256 value) internal {
        // checked; will revert if supply overflows.
        _stakeTotalSupply += value;
        unchecked {
            // unchecked; totalsupply will overflow before balance for a given
            // account does.
            _stakeBalances[tokenId] += value;
        }
    }

    /**
     * @notice Burn from staking account for a tokenId account.
     */
    function _burnStake(uint256 tokenId, uint256 value) internal {
        uint256 currentBalance = _stakeBalances[tokenId];
        if (value > currentBalance) revert InsufficientBalance(tokenId, currentBalance, value);
        unchecked {
            _stakeTotalSupply -= value;
            _stakeBalances[tokenId] = currentBalance - value;
        }
    }
}
