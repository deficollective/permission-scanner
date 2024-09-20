// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MaverickV2VotingEscrow} from "./MaverickV2VotingEscrow.sol";
import {IMaverickV2VotingEscrowWSync} from "./interfaces/IMaverickV2VotingEscrowWSync.sol";
import {IMaverickV2VotingEscrowFactory} from "./interfaces/IMaverickV2VotingEscrowFactory.sol";
import {ILegacyVeMav} from "./votingescrowbase/ILegacyVeMav.sol";

/**
 * @notice Inherits MaverickV2VotingEscrow and adds functionality for
 * synchronizing veMav V1 and veMav v2 balances.
 */
contract MaverickV2VotingEscrowWSync is MaverickV2VotingEscrow, IMaverickV2VotingEscrowWSync {
    /// @inheritdoc IMaverickV2VotingEscrowWSync
    IERC20 public immutable legacyVeMav;

    /// @inheritdoc IMaverickV2VotingEscrowWSync
    mapping(address staker => mapping(uint256 legacyLockupIndex => uint256 balance)) public syncBalances;
    /// @inheritdoc IMaverickV2VotingEscrowWSync
    uint256 public constant MIN_SYNC_DURATION = 365 days;

    constructor(string memory __name, string memory __symbol) MaverickV2VotingEscrow(__name, __symbol) {
        legacyVeMav = IMaverickV2VotingEscrowFactory(msg.sender).legacyVeMav();

        startTimestamp = ILegacyVeMav(address(legacyVeMav)).epoch();
    }

    /// @inheritdoc IMaverickV2VotingEscrowWSync
    function sync(address staker, uint256 legacyLockupIndex) public nonReentrant returns (uint256 newBalance) {
        mapping(uint256 => uint256) storage stakerBalancePerIndex = syncBalances[staker];
        uint256 oldBalance = stakerBalancePerIndex[legacyLockupIndex];
        Lockup memory lockup = ILegacyVeMav(address(legacyVeMav)).lockups(staker, legacyLockupIndex);
        if (lockup.end != 0 && lockup.end < block.timestamp + MIN_SYNC_DURATION)
            revert VotingEscrowLockupEndTooShortToSync(lockup.end, block.timestamp + MIN_SYNC_DURATION);

        newBalance = lockup.votes;
        if (newBalance != oldBalance) {
            unchecked {
                if (newBalance > oldBalance) {
                    _mint(staker, newBalance - oldBalance);
                } else if (newBalance < oldBalance) {
                    _burn(staker, oldBalance - newBalance);
                }
            }
            stakerBalancePerIndex[legacyLockupIndex] = newBalance;
            emit Sync(staker, legacyLockupIndex, newBalance);
        }
    }
}
