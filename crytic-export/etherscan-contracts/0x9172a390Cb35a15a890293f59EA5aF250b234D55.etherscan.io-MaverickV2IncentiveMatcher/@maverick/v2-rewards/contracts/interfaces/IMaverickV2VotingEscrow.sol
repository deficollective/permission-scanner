// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";

import {IHistoricalBalance} from "../votingescrowbase/IHistoricalBalance.sol";

interface IMaverickV2VotingEscrowBase is IVotes, IHistoricalBalance {
    error VotingEscrowTransferNotSupported();
    error VotingEscrowInvalidAddress(address);
    error VotingEscrowInvalidAmount(uint256);
    error VotingEscrowInvalidDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);
    error VotingEscrowInvalidEndTime(uint256 newEnd, uint256 oldEnd);
    error VotingEscrowStakeStillLocked(uint256 currentTime, uint256 endTime);
    error VotingEscrowStakeAlreadyRedeemed();
    error VotingEscrowNotApprovedExtender(address account, address extender, uint256 lockupId);
    error VotingEscrowIncentiveAlreadyClaimed(address account, uint256 batchIndex);
    error VotingEscrowNoIncentivesToClaim(address account, uint256 batchIndex);
    error VotingEscrowInvalidExtendIncentiveToken(IERC20 incentiveToken);
    error VotingEscrowNoSupplyAtTimepoint();
    error VotingEscrowIncentiveTimepointInFuture(uint256 timestamp, uint256 claimTimepoint);

    event Stake(address indexed user, uint256 lockupId, Lockup);
    event Unstake(address indexed user, uint256 lockupId, Lockup);
    event ExtenderApproval(address staker, address extender, uint256 lockupId, bool newState);
    event ClaimIncentiveBatch(uint256 batchIndex, address account, uint256 claimAmount);
    event CreateNewIncentiveBatch(
        address user,
        uint256 amount,
        uint256 timepoint,
        uint256 stakeDuration,
        IERC20 incentiveToken
    );

    struct Lockup {
        uint128 amount;
        uint128 end;
        uint256 votes;
    }

    struct ClaimInformation {
        bool timepointInPast;
        bool hasClaimed;
        uint128 claimAmount;
    }

    struct BatchInformation {
        uint128 totalIncentives;
        uint128 stakeDuration;
        uint48 claimTimepoint;
        IERC20 incentiveToken;
    }

    struct TokenIncentiveTotals {
        uint128 totalIncentives;
        uint128 claimedIncentives;
    }

    // solhint-disable-next-line func-name-mixedcase
    function MIN_STAKE_DURATION() external returns (uint256 duration);

    // solhint-disable-next-line func-name-mixedcase
    function MAX_STAKE_DURATION() external returns (uint256 duration);

    // solhint-disable-next-line func-name-mixedcase
    function YEAR_BASE() external returns (uint256);

    /**
     * @notice This function retrieves the address of the ERC20 token used as the base token for staking and rewards.
     * @return baseToken The address of the IERC20 base token contract.
     */
    function baseToken() external returns (IERC20);

    /**
     * @notice This function retrieves the starting timestamp. This may be used
     * for reward calculations or other time-based logic.
     */
    function startTimestamp() external returns (uint256 timestamp);

    /**
     * @notice This function retrieves the details of a specific lockup for a given staker and lockup index.
     * @param staker The address of the staker for which to retrieve the lockup details.
     * @param index The index of the lockup within the staker's lockup history.
     * @return lockup A Lockup struct containing details about the lockup (see struct definition for details).
     */
    function getLockup(address staker, uint256 index) external view returns (Lockup memory lockup);

    /**
     * @notice This function retrieves the total number of lockups associated with a specific staker.
     * @param staker The address of the staker for which to retrieve the lockup count.
     * @return count The total number of lockups for the staker.
     */
    function lockupCount(address staker) external view returns (uint256 count);

    /**
     * @notice This function simulates a lockup scenario, providing details about the resulting lockup structure for a specified amount and duration.
     * @param amount The amount of tokens to be locked.
     * @param duration The duration of the lockup period.
     * @return lockup A Lockup struct containing details about the simulated lockup (see struct definition for details).
     */
    function previewVotes(uint128 amount, uint256 duration) external view returns (Lockup memory lockup);

    /**
     * @notice This function grants approval for a designated extender contract to manage a specific lockup on behalf of the staker.
     * @param extender The address of the extender contract to be approved.
     * @param lockupId The ID of the lockup for which to grant approval.
     */
    function approveExtender(address extender, uint256 lockupId) external;

    /**
     * @notice This function revokes approval previously granted to an extender contract for managing a specific lockup.
     * @param extender The address of the extender contract whose approval is being revoked.
     * @param lockupId The ID of the lockup for which to revoke approval.
     */
    function revokeExtender(address extender, uint256 lockupId) external;

    /**
     * @notice This function checks whether a specific account has been approved by a staker to manage a particular lockup through an extender contract.
     * @param account The address of the account to check for approval (may be the extender or another account).
     * @param extender The address of the extender contract for which to check approval.
     * @param lockupId The ID of the lockup to verify approval for.
     * @return isApproved True if the account is approved for the lockup, False otherwise (bool).
     */
    function isApprovedExtender(address account, address extender, uint256 lockupId) external view returns (bool);

    /**
     * @notice This function extends the lockup period for the caller (msg.sender) for a specified lockup ID, adding a new duration and amount.
     * @param lockupId The ID of the lockup to be extended.
     * @param duration The additional duration to extend the lockup by.
     * @param amount The additional amount of tokens to be locked.
     * @return newLockup A Lockup struct containing details about the newly extended lockup (see struct definition for details).
     */
    function extendForSender(
        uint256 lockupId,
        uint256 duration,
        uint128 amount
    ) external returns (Lockup memory newLockup);

    /**
     * @notice This function extends the lockup period for a specified account, adding a new duration and amount. The caller (msg.sender) must be authorized to manage the lockup through an extender contract.
     * @param account The address of the account whose lockup is being extended.
     * @param lockupId The ID of the lockup to be extended.
     * @param duration The additional duration to extend the lockup by.
     * @param amount The additional amount of tokens to be locked.
     * @return newLockup A Lockup struct containing details about the newly extended lockup (see struct definition for details).
     */
    function extendForAccount(
        address account,
        uint256 lockupId,
        uint256 duration,
        uint128 amount
    ) external returns (Lockup memory newLockup);

    /**
     * @notice This function merges multiple lockups associated with the caller
     * (msg.sender) into a single new lockup.
     * @param lockupIds An array containing the IDs of the lockups to be merged.
     * @return newLockup A Lockup struct containing details about the newly merged lockup (see struct definition for details).
     */
    function merge(uint256[] memory lockupIds) external returns (Lockup memory newLockup);

    /**
     * @notice This function unstakes the specified lockup ID for the caller (msg.sender), returning the details of the unstaked lockup.
     * @param lockupId The ID of the lockup to be unstaked.
     * @param to The address to which the unstaked tokens should be sent (optional, defaults to msg.sender).
     * @return lockup A Lockup struct containing details about the unstaked lockup (see struct definition for details).
     */
    function unstake(uint256 lockupId, address to) external returns (Lockup memory lockup);

    /**
     * @notice This function is a simplified version of `unstake` that automatically sends the unstaked tokens to the caller (msg.sender).
     * @param lockupId The ID of the lockup to be unstaked.
     * @return lockup A Lockup struct containing details about the unstaked lockup (see struct definition for details).
     */
    function unstakeToSender(uint256 lockupId) external returns (Lockup memory lockup);

    /**
     * @notice This function stakes a specified amount of tokens for the caller
     * (msg.sender) for a defined duration.
     * @param amount The amount of tokens to be staked.
     * @param duration The duration of the lockup period.
     * @return lockup A Lockup struct containing details about the newly
     * created lockup (see struct definition for details).
     */
    function stakeToSender(uint128 amount, uint256 duration) external returns (Lockup memory lockup);

    /**
     * @notice This function stakes a specified amount of tokens for a defined
     * duration, allowing the caller (msg.sender) to specify an optional
     * recipient for the staked tokens.
     * @param amount The amount of tokens to be staked.
     * @param duration The duration of the lockup period.
     * @param to The address to which the staked tokens will be credited (optional, defaults to msg.sender).
     * @return lockup A Lockup struct containing details about the newly
     * created lockup (see struct definition for details).
     */
    function stake(uint128 amount, uint256 duration, address to) external returns (Lockup memory);

    /**
     * @notice This function retrieves the total incentive information for a specific ERC-20 token.
     * @param token The address of the ERC20 token for which to retrieve incentive totals.
     * @return totals A TokenIncentiveTotals struct containing details about
     * the token's incentives (see struct definition for details).
     */
    function incentiveTotals(IERC20 token) external view returns (TokenIncentiveTotals memory);

    /**
     * @notice This function retrieves the total number of created incentive batches.
     * @return count The total number of incentive batches.
     */
    function incentiveBatchCount() external view returns (uint256);

    /**
     * @notice This function retrieves claim information for a specific account and incentive batch index.
     * @param account The address of the account for which to retrieve claim information.
     * @param batchIndex The index of the incentive batch for which to retrieve
     * claim information.
     * @return claimInformation A ClaimInformation struct containing details about the
     * account's claims for the specified batch (see struct definition for
     * details).
     * @return batchInformation A BatchInformation struct containing details about the
     * specified batch (see struct definition for details).
     */
    function claimAndBatchInformation(
        address account,
        uint256 batchIndex
    ) external view returns (ClaimInformation memory claimInformation, BatchInformation memory batchInformation);

    /**
     * @notice This function retrieves batch information for a incentive batch index.
     * @param batchIndex The index of the incentive batch for which to retrieve
     * claim information.
     * @return info A BatchInformation struct containing details about the
     * specified batch (see struct definition for details).
     */
    function incentiveBatchInformation(uint256 batchIndex) external view returns (BatchInformation memory info);

    /**
     * @notice This function allows claiming rewards from a specific incentive
     * batch while simultaneously extending a lockup with the claimed tokens.
     * @param batchIndex The index of the incentive batch from which to claim rewards.
     * @param lockupId The ID of the lockup to be extended with the claimed tokens.
     * @return lockup A Lockup struct containing details about the updated
     * lockup after extension (see struct definition for details).
     * @return claimAmount The amount of tokens claimed from the incentive batch.
     */
    function claimFromIncentiveBatchAndExtend(
        uint256 batchIndex,
        uint256 lockupId
    ) external returns (Lockup memory lockup, uint128 claimAmount);

    /**
     * @notice This function allows claiming rewards from a specific incentive
     * batch, without extending any lockups.
     * @param batchIndex The index of the incentive batch from which to claim rewards.
     * @return lockup A Lockup struct containing details about the user's
     * lockup that might have been affected by the claim (see struct definition
     * for details).
     * @return claimAmount The amount of tokens claimed from the incentive batch.
     */
    function claimFromIncentiveBatch(uint256 batchIndex) external returns (Lockup memory lockup, uint128 claimAmount);

    /**
     * @notice This function creates a new incentive batch for a specified amount
     * of incentive tokens, timepoint, stake duration, and associated ERC-20
     * token. An incentive batch is a reward of incentives put up by the
     * caller at a certain timepoint.  The incentive batch is claimable by ve
     * holders after the timepoint has passed.  The ve holders will receive
     * their incentive pro rata of their vote balance (`pastbalanceOf`) at that
     * timepoint.  The incentivizer can specify that users have to stake the
     * resulting incentive for a given `stakeDuration` number of seconds.
     * `stakeDuration` can either be zero, meaning that no staking is required
     * on redemption, or can be a number between `MIN_STAKE_DURATION()` and
     * `MAX_STAKE_DURATION()`.
     * @param amount The total amount of incentive tokens to be distributed in the batch.
     * @param timepoint The timepoint at which the incentive batch starts accruing rewards.
     * @param stakeDuration The duration of the lockup period required to be
     * eligible for the incentive batch rewards.
     * @param incentiveToken The address of the ERC20 token used for the incentive rewards.
     * @return index The index of the newly created incentive batch.
     */
    function createIncentiveBatch(
        uint128 amount,
        uint48 timepoint,
        uint128 stakeDuration,
        IERC20 incentiveToken
    ) external returns (uint256 index);
}

interface IMaverickV2VotingEscrow is IMaverickV2VotingEscrowBase, IERC20Metadata, IERC6372 {}
