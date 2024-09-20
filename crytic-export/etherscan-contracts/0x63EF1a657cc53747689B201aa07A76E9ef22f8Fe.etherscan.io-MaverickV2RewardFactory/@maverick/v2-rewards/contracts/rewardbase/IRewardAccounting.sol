// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

interface IRewardAccounting {
    error InsufficientBalance(uint256 tokenId, uint256 currentBalance, uint256 value);

    /**
     * @notice Balance of stake for a given `tokenId` account.
     */
    function stakeBalanceOf(uint256 tokenId) external view returns (uint256 balance);

    /**
     * @notice Sum of all balances across all tokenIds.
     */
    function stakeTotalSupply() external view returns (uint256 supply);
}
