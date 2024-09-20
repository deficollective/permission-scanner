// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math as OzMath} from "@openzeppelin/contracts/utils/math/Math.sol";

import {VotingEscrow} from "./votingescrowbase/VotingEscrow.sol";
import {IMaverickV2VotingEscrowBase} from "./interfaces/IMaverickV2VotingEscrow.sol";

/**
 * @notice Provides staking, vote power history, vote delegation, and incentive
 * disbursement to ve holders.
 *
 * @dev `VotingEscrow` contract provides details on the staking and delegation
 * features.
 *
 * @dev Incentive disbursement can take place in any token and happens when a
 * user permissionlessly creates a new incentive batch for a specified amount
 * of incentive tokens, timepoint, stake duration, and associated ERC-20 token.
 * An incentive batch is a reward of incentives put up by the caller at a
 * certain timepoint.  The incentive batch is claimable by ve holders after the
 * timepoint has passed.  The ve holders will receive their incentive pro rata
 * of their vote balance (`pastbalanceOf`) at that timepoint.  The incentivizer
 * can specify that users have to stake the resulting incentive for a given
 * `stakeDuration` number of seconds. `stakeDuration` can either be zero,
 * meaning that no staking is required on redemption, or can be a number
 * between `MIN_STAKE_DURATION()` and `MAX_STAKE_DURATION()`.
 */
contract MaverickV2VotingEscrow is VotingEscrow {
    using SafeERC20 for IERC20;
    using Cast for uint256;

    struct IncentiveSpecification {
        BatchInformation batchInformation;
        mapping(address => bool) hasClaimed;
    }

    mapping(uint256 => IncentiveSpecification) private _incentiveBatches;

    mapping(IERC20 => TokenIncentiveTotals) private _tokenIncentiveTotals;

    /// @inheritdoc IMaverickV2VotingEscrowBase
    uint256 public incentiveBatchCount;

    constructor(string memory __name, string memory __symbol) VotingEscrow(__name, __symbol) {}

    //////////////////////
    // Incentive Functions
    //////////////////////

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function createIncentiveBatch(
        uint128 amount,
        uint48 timepoint,
        uint128 stakeDuration,
        IERC20 incentiveToken
    ) public returns (uint256 index) {
        if (amount == 0) revert VotingEscrowInvalidAmount(amount);
        if (stakeDuration != 0) {
            if (incentiveToken == baseToken) {
                _checkDuration(stakeDuration);
            } else {
                // if not base token, stakeDuration should be zero
                revert VotingEscrowInvalidDuration(stakeDuration, 0, 0);
            }
        }

        index = incentiveBatchCount;

        _tokenIncentiveTotals[incentiveToken].totalIncentives += amount;
        IncentiveSpecification storage spec = _incentiveBatches[index];

        spec.batchInformation.totalIncentives = amount;
        spec.batchInformation.incentiveToken = incentiveToken;
        spec.batchInformation.claimTimepoint = timepoint;
        spec.batchInformation.stakeDuration = stakeDuration;
        incentiveBatchCount++;

        incentiveToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CreateNewIncentiveBatch(msg.sender, amount, timepoint, stakeDuration, incentiveToken);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function claimFromIncentiveBatch(uint256 batchIndex) public returns (Lockup memory lockup, uint128 claimAmount) {
        uint256 stakeDuration;
        IERC20 incentiveToken;
        (claimAmount, stakeDuration, incentiveToken) = _claim(batchIndex);

        if (incentiveToken == baseToken && stakeDuration != 0) {
            // no need to transfer; the base assets are already on this contract
            lockup = _stake(claimAmount, stakeDuration, msg.sender, type(uint256).max);
        } else {
            incentiveToken.safeTransfer(msg.sender, claimAmount);
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function claimFromIncentiveBatchAndExtend(
        uint256 batchIndex,
        uint256 lockupId
    ) public returns (Lockup memory lockup, uint128 claimAmount) {
        uint256 stakeDuration;
        IERC20 incentiveToken;
        (claimAmount, stakeDuration, incentiveToken) = _claim(batchIndex);

        if (incentiveToken == baseToken && stakeDuration != 0) {
            // no need to transfer; the base assets are already on this contract
            lockup = _extend(claimAmount, stakeDuration, msg.sender, lockupId);
        } else {
            revert VotingEscrowInvalidExtendIncentiveToken(incentiveToken);
        }
    }

    //////////////////////
    // View Functions
    //////////////////////

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function incentiveTotals(IERC20 incentiveToken) external view returns (TokenIncentiveTotals memory totals) {
        totals = _tokenIncentiveTotals[incentiveToken];
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function claimAndBatchInformation(
        address account,
        uint256 batchIndex
    ) public view returns (ClaimInformation memory claimInformation, BatchInformation memory batchInformation) {
        IncentiveSpecification storage spec = _incentiveBatches[batchIndex];
        batchInformation = spec.batchInformation;

        uint48 timepoint = batchInformation.claimTimepoint;
        claimInformation.timepointInPast = timepoint < block.timestamp;

        if (claimInformation.timepointInPast) {
            claimInformation.claimAmount = OzMath
                .mulDiv(
                    batchInformation.totalIncentives,
                    getPastBalanceOf(account, timepoint),
                    getPastTotalSupply(timepoint)
                )
                .toUint128();
            claimInformation.hasClaimed = spec.hasClaimed[account];
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function incentiveBatchInformation(uint256 batchIndex) public view returns (BatchInformation memory info) {
        info = _incentiveBatches[batchIndex].batchInformation;
    }

    //////////////////////
    // Internal Functions
    //////////////////////

    function _claim(
        uint256 batchIndex
    ) internal returns (uint128 claimAmount, uint256 stakeDuration, IERC20 incentiveToken) {
        (ClaimInformation memory claimInformation, BatchInformation memory batchInformation) = claimAndBatchInformation(
            msg.sender,
            batchIndex
        );

        if (!claimInformation.timepointInPast)
            revert VotingEscrowIncentiveTimepointInFuture(block.timestamp, batchInformation.claimTimepoint);
        if (claimInformation.claimAmount == 0) revert VotingEscrowNoIncentivesToClaim(msg.sender, batchIndex);
        if (claimInformation.hasClaimed) revert VotingEscrowIncentiveAlreadyClaimed(msg.sender, batchIndex);

        _tokenIncentiveTotals[batchInformation.incentiveToken].claimedIncentives += claimInformation.claimAmount;
        _incentiveBatches[batchIndex].hasClaimed[msg.sender] = true;

        emit ClaimIncentiveBatch(batchIndex, msg.sender, claimInformation.claimAmount);
        return (claimInformation.claimAmount, batchInformation.stakeDuration, batchInformation.incentiveToken);
    }
}
