// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMaverickV2VotingEscrowWSync {
    error VotingEscrowLockupEndTooShortToSync(uint256 legacyLockupEnd, uint256 minimumLockupEnd);

    event Sync(address staker, uint256 legacyLockupIndex, uint256 newBalance);

    /**
     * @notice This function retrieves the minimum lockup duration required for
     * a legacy lockup to be eligible for synchronization.
     * @return minSyncDuration The minimum allowed lockup end time.
     */
    // solhint-disable-next-line func-name-mixedcase
    function MIN_SYNC_DURATION() external pure returns (uint256 minSyncDuration);

    /**
     * @notice This function retrieves the address of the legacy Maverick V1
     * Voting Escrow (veMav) token.
     * @return legacyVeMav The address of the IERC20 legacy veMav token.
     */
    function legacyVeMav() external view returns (IERC20);

    /**
     * @notice This function retrieves the synced balance for a specific legacy lockup index of a user.
     * @param staker The address of the user for whom to retrieve the synced balance.
     * @param legacyLockupIndex The index of the legacy lockup for which to
     * retrieve the synced balance.
     * @return balance The synced balance associated with the legacy lockup.
     */
    function syncBalances(address staker, uint256 legacyLockupIndex) external view returns (uint256 balance);

    /**
     * @notice This function synchronizes a specific legacy lockup index for a
     * user within the contract.  If the legacy lockup.end is not at least
     * `block.timestamp + MIN_SYNC_DURATION()`, this function will revert.
     * @param staker The address of the user for whom to perform synchronization.
     * @param legacyLockupIndex The index of the legacy lockup to be
     * synchronized.
     * @return newBalance The new balance resulting from the synchronization
     * process.
     */
    function sync(address staker, uint256 legacyLockupIndex) external returns (uint256 newBalance);
}
