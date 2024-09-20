// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

interface IHistoricalBalance {
    /**
     * @notice This function retrieves the historical balance of an account at
     * a specific point in time.
     * @param account The address of the account for which to retrieve the
     * historical balance.
     * @param timepoint The timepoint (block number or timestamp depending on
     * implementation) at which to query the balance (uint256).
     * @return balance The balance of the account at the specified timepoint.
     */
    function getPastBalanceOf(address account, uint256 timepoint) external view returns (uint256 balance);
}
