// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ud} from "@prb/math/src/UD60x18.sol";
import {pow} from "@prb/math/src/ud60x18/Math.sol";

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {Multicall} from "@maverick/v2-common/contracts/base/Multicall.sol";

import {IMaverickV2VotingEscrowBase} from "../interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2VotingEscrowFactory} from "../interfaces/IMaverickV2VotingEscrowFactory.sol";
import {HistoricalBalance} from "./HistoricalBalance.sol";

// forked from https://github.com/OriginProtocol/ousd-governance/blob/5a6ed042feef6973177e3b1b093c5a6e64039de4/contracts/OgvStaking.sol

/**
 * @notice Provides staking, vote power history, vote delegation.
 *
 * The balance received for staking (and thus the voting power) goes up
 * exponentially by the end of the staked period.
 */
abstract contract VotingEscrow is HistoricalBalance, IMaverickV2VotingEscrowBase, ReentrancyGuard, Multicall {
    using SafeERC20 for IERC20;
    using Cast for uint256;

    /// @inheritdoc IMaverickV2VotingEscrowBase
    uint256 public constant YEAR_BASE = 1.5e18;
    /// @inheritdoc IMaverickV2VotingEscrowBase
    uint256 public immutable startTimestamp;
    /// @inheritdoc IMaverickV2VotingEscrowBase
    uint256 public constant MIN_STAKE_DURATION = 4 weeks;
    /// @inheritdoc IMaverickV2VotingEscrowBase
    uint256 public constant MAX_STAKE_DURATION = 4 * (365 days);

    mapping(address => Lockup[]) internal _lockups;
    mapping(address => mapping(address => mapping(uint256 => bool))) internal _extenders;

    /// @inheritdoc IMaverickV2VotingEscrowBase
    IERC20 public immutable baseToken;

    constructor(string memory __name, string memory __symbol) ERC20(__name, __symbol) EIP712(__name, "1") {
        baseToken = IMaverickV2VotingEscrowFactory(msg.sender).baseTokenParameter();
        startTimestamp = block.timestamp;
    }

    //////////////////////
    // Internal State-Modifying Functions
    //////////////////////

    /**
     *
     * @notice Internal function that stakes an amount for a duration to an address.
     * @dev This function validates that `to` is not the zero address and that the
     * duration is within bounds.
     * @dev Function also does a transferFrom for the base token amount.  This
     * requires that the sender approve this ve contract to be able to transfer
     * tokens for the sender.
     *
     */
    function _stake(
        uint128 amount,
        uint256 duration,
        address to,
        uint256 lockupId
    ) internal nonReentrant returns (Lockup memory lockup) {
        if (to == address(0)) revert VotingEscrowInvalidAddress(to);

        // duration checks applied inside previewVotes
        lockup = previewVotes(amount, duration);

        // stake to existing or new lockup
        if (lockupId >= lockupCount(to)) {
            _lockups[to].push(lockup);
            unchecked {
                lockupId = _lockups[to].length - 1;
            }
        } else {
            _lockups[to][lockupId] = lockup;
        }

        // mint ve votes
        _mint(to, lockup.votes);

        emit Stake(to, lockupId, lockup);
    }

    /**
     *
     * @notice Internal function that unstakes an account's lockup.
     *
     * @dev This function validates that the lockup has not already been
     * claimed and does burn the account's voting votes.
     *
     * @dev But the function does not transfer the baseTokens to the staker.
     * That transfer operation must be executed seperately as appropiate.
     *
     * @dev This function also does not validate that the lockup end time has
     * passed nor does it validate that `account` has permissions to unstake
     * this lockupId.
     *
     */
    function _unstake(address account, uint256 lockupId) internal returns (Lockup memory lockup) {
        lockup = _lockups[account][lockupId];

        if (lockup.end == 0) revert VotingEscrowStakeAlreadyRedeemed();

        delete _lockups[account][lockupId]; // Keeps empty in array, so indexes are stable

        _burn(account, lockup.votes);

        emit Unstake(account, lockupId, lockup);
    }

    /**
     *
     * @notice Internal function that extends an account's lockup.
     *
     * @dev This function validates that the lockup has not already been
     * claimed.
     *
     * @dev This function also does not validate that the `account` has
     * permissions to unstake this lockupId.
     *
     */
    function _extend(
        uint128 amount,
        uint256 duration,
        address account,
        uint256 lockupId
    ) internal returns (Lockup memory newLockup) {
        // unstake existing lockup
        Lockup memory oldLockup = _unstake(account, lockupId);

        // stake new lockup
        newLockup = _stake(oldLockup.amount + amount, duration, account, lockupId);

        // ensure the new lock is at least as long as old lock
        if (newLockup.end < oldLockup.end) revert VotingEscrowInvalidEndTime(newLockup.end, oldLockup.end);
    }

    //////////////////////
    // Public Stake-Management Functions
    //////////////////////

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function stake(uint128 amount, uint256 duration, address to) public returns (Lockup memory lockup) {
        if (amount == 0) revert VotingEscrowInvalidAmount(amount);
        lockup = _stake(amount, duration, to, type(uint256).max);
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function stakeToSender(uint128 amount, uint256 duration) public virtual returns (Lockup memory lockup) {
        return stake(amount, duration, msg.sender);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function unstake(uint256 lockupId, address to) public nonReentrant returns (Lockup memory lockup) {
        lockup = _unstake(msg.sender, lockupId);

        if (block.timestamp < lockup.end) revert VotingEscrowStakeStillLocked(block.timestamp, lockup.end);

        baseToken.safeTransfer(to, lockup.amount);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function unstakeToSender(uint256 lockupId) public returns (Lockup memory lockup) {
        return unstake(lockupId, msg.sender);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function merge(uint256[] memory lockupIds) public returns (Lockup memory newLockup) {
        uint128 cumulativeAmount;
        uint256 maxEnd;

        Lockup memory oldLockup;
        for (uint256 k; k < lockupIds.length; k++) {
            oldLockup = _unstake(msg.sender, lockupIds[k]);
            cumulativeAmount += oldLockup.amount;
            maxEnd = Math.max(maxEnd, oldLockup.end);
        }

        // stake new lockup; checks to ensure new duration is at least min duration.
        newLockup = _stake(cumulativeAmount, maxEnd - block.timestamp, msg.sender, lockupIds[0]);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function extendForSender(
        uint256 lockupId,
        uint256 duration,
        uint128 amount
    ) public virtual returns (Lockup memory newLockup) {
        newLockup = _extend(amount, duration, msg.sender, lockupId);
        if (amount != 0) baseToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function extendForAccount(
        address account,
        uint256 lockupId,
        uint256 duration,
        uint128 amount
    ) public returns (Lockup memory newLockup) {
        _checkApprovedExtender(account, lockupId);
        newLockup = _extend(amount, duration, account, lockupId);
        if (amount != 0) baseToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    //////////////////////
    // Permissioning Functions
    //////////////////////

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function approveExtender(address extender, uint256 lockupId) public {
        _extenders[extender][msg.sender][lockupId] = true;
        emit ExtenderApproval(msg.sender, extender, lockupId, true);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function revokeExtender(address extender, uint256 lockupId) public {
        _extenders[extender][msg.sender][lockupId] = false;
        emit ExtenderApproval(msg.sender, extender, lockupId, false);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function isApprovedExtender(address account, address extender, uint256 lockupId) public view returns (bool) {
        return _extenders[extender][account][lockupId];
    }

    function _checkApprovedExtender(address account, uint256 lockupId) internal view {
        bool approved = isApprovedExtender(account, msg.sender, lockupId);
        if (!approved && account != msg.sender) revert VotingEscrowNotApprovedExtender(account, msg.sender, lockupId);
    }

    //////////////////////
    // View Functions
    //////////////////////

    function _checkDuration(uint256 duration) internal pure {
        if (duration < MIN_STAKE_DURATION || duration > MAX_STAKE_DURATION)
            revert VotingEscrowInvalidDuration(duration, MIN_STAKE_DURATION, MAX_STAKE_DURATION);
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function previewVotes(uint128 amount, uint256 duration) public view returns (Lockup memory lockup) {
        _checkDuration(duration);
        unchecked {
            // duration has been validated to be a small number, can do an
            // unsafe cast and add
            lockup.end = uint128(block.timestamp + duration);
            uint256 endYearpoc = Math.divFloor((lockup.end - startTimestamp), 365 days);
            uint256 multiplier = pow(ud(YEAR_BASE), ud(endYearpoc)).unwrap();
            lockup.amount = amount;
            lockup.votes = Math.mulFloor(amount, multiplier);
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function getLockup(address staker, uint256 index) public view returns (Lockup memory lockup) {
        return _lockups[staker][index];
    }

    /// @inheritdoc IMaverickV2VotingEscrowBase
    function lockupCount(address staker) public view returns (uint256 count) {
        return _lockups[staker].length;
    }

    //////////////////////
    // Overrides
    //////////////////////

    /**
     * @notice Transfers of voting balances are not allowed.  This function will revert.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert VotingEscrowTransferNotSupported();
    }

    /**
     * @notice Transfers of voting balances are not allowed.  This function will revert.
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert VotingEscrowTransferNotSupported();
    }

    /**
     * @notice Transfers of voting balances are not allowed.  This function will revert.
     */
    function approve(address, uint256) public pure override returns (bool) {
        revert VotingEscrowTransferNotSupported();
    }
}
