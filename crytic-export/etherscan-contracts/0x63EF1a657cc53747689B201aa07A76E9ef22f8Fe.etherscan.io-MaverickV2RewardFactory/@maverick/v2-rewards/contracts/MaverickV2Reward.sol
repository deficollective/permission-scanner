// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ONE} from "@maverick/v2-common/contracts/libraries/Constants.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {Multicall} from "@maverick/v2-common/contracts/base/Multicall.sol";
import {Nft} from "@maverick/v2-supplemental/contracts/positionbase/Nft.sol";
import {INft} from "@maverick/v2-supplemental/contracts/positionbase/INft.sol";

import {IMaverickV2Reward} from "./interfaces/IMaverickV2Reward.sol";
import {RewardAccounting} from "./rewardbase/RewardAccounting.sol";
import {MaverickV2RewardVault, IMaverickV2RewardVault} from "./MaverickV2RewardVault.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";

/**
 * @notice This reward contract is used to reward users who stake their
 * `stakingToken` in this contract. The `stakingToken` can be any token with an
 * ERC-20 interface including BoostedPosition LP tokens.
 *
 * @notice Incentive providers can permissionlessly add incentives to this
 * contract that will be disbursed to stakers pro rata over a given duration that
 * the incentive provider specifies as they add incentives.
 *
 * Incentives can be denominated in one of 5 possible reward tokens that the
 * reward contract creator specifies on contract creation.
 *
 * @notice The contract creator also has the option of specifying veTokens
 * associated with each of the up-to-5 reward tokens.  When incentivizing a
 * rewardToken that has a veToken specified, the staking users will receive a
 * boost to their rewards depending on 1) how much ve tokens they own and 2) how
 * long they stake their rewards disbursement.
 */
contract MaverickV2Reward is Nft, RewardAccounting, IMaverickV2Reward, Multicall, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Cast for uint256;

    uint256 internal constant FOUR_YEARS = 1460 days;
    uint256 internal constant BASE_STAKING_FACTOR = 0.2e18;
    uint256 internal constant STAKING_FACTOR_SLOPE = 0.8e18;
    uint256 internal constant BASE_PRORATA_FACTOR = 0.75e18;
    uint256 internal constant PRORATA_FACTOR_SLOPE = 0.25e18;

    /// @inheritdoc IMaverickV2Reward
    uint256 public constant UNBOOSTED_MIN_TIME_GAP = 13 weeks;

    /// @inheritdoc IMaverickV2Reward
    IERC20 public immutable stakingToken;

    IERC20 private immutable rewardToken0;
    IERC20 private immutable rewardToken1;
    IERC20 private immutable rewardToken2;
    IERC20 private immutable rewardToken3;
    IERC20 private immutable rewardToken4;
    IMaverickV2VotingEscrow private immutable veToken0;
    IMaverickV2VotingEscrow private immutable veToken1;
    IMaverickV2VotingEscrow private immutable veToken2;
    IMaverickV2VotingEscrow private immutable veToken3;
    IMaverickV2VotingEscrow private immutable veToken4;

    /// @inheritdoc IMaverickV2Reward
    uint256 public constant MAX_DURATION = 40 days;
    /// @inheritdoc IMaverickV2Reward
    uint256 public constant MIN_DURATION = 3 days;

    struct RewardData {
        // Timestamp of when the rewards finish
        uint64 finishAt;
        // Minimum of last updated time and reward finish time
        uint64 updatedAt;
        // Reward to be paid out per second
        uint128 rewardRate;
        // Reward amount escrowed for staked users up to current time. this
        // value is incremented on each action as by the amount of reward
        // globally accumulated since the last action.  when a user collects
        // reward, this amount is decremented.
        uint128 escrowedReward;
        // Accumulator of the amount of this reward token not taken as part of
        // getReward boosting.  this amount gets pushed to the associated ve
        // contract as an incentive for the ve holders.
        uint128 unboostedAmount;
        // Timestamp of last time unboosted reward was pushed to ve contract as
        // incentive
        uint256 lastUnboostedPushTimestamp;
        // Sum of (reward rate * dt * 1e18 / total supply)
        uint256 rewardPerTokenStored;
        // User tokenId => rewardPerTokenStored
        mapping(uint256 tokenId => uint256) userRewardPerTokenPaid;
        // User tokenId => rewards to be claimed
        mapping(uint256 tokenId => uint128) rewards;
    }
    RewardData[5] public rewardData;

    uint256 public immutable rewardTokenCount;
    IMaverickV2RewardVault public immutable vault;

    constructor(
        string memory name_,
        string memory symbol_,
        IERC20 _stakingToken,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    ) Nft(name_, symbol_) {
        stakingToken = _stakingToken;
        vault = new MaverickV2RewardVault(_stakingToken);
        rewardTokenCount = rewardTokens.length;
        if (rewardTokenCount > 0) {
            rewardToken0 = rewardTokens[0];
            veToken0 = veTokens[0];
        }
        if (rewardTokenCount > 1) {
            rewardToken1 = rewardTokens[1];
            veToken1 = veTokens[1];
        }
        if (rewardTokenCount > 2) {
            rewardToken2 = rewardTokens[2];
            veToken2 = veTokens[2];
        }
        if (rewardTokenCount > 3) {
            rewardToken3 = rewardTokens[3];
            veToken3 = veTokens[3];
        }
        if (rewardTokenCount > 4) {
            rewardToken4 = rewardTokens[4];
            veToken4 = veTokens[4];
        }
    }

    modifier checkAmount(uint256 amount) {
        if (amount == 0) revert RewardZeroAmount();
        _;
    }

    /////////////////////////////////////
    /// Stake Management Functions
    /////////////////////////////////////

    /// @inheritdoc IMaverickV2Reward
    function mint(address recipient) public returns (uint256 tokenId) {
        tokenId = _mint(recipient);
    }

    /// @inheritdoc IMaverickV2Reward
    function mintToSender() public returns (uint256 tokenId) {
        tokenId = _mint(msg.sender);
    }

    /// @inheritdoc IMaverickV2Reward
    function stake(uint256 tokenId) public returns (uint256 amount, uint256 stakedTokenId) {
        // reverts if token is not owned
        stakedTokenId = tokenId;
        if (stakedTokenId == 0) {
            if (tokenOfOwnerByIndexExists(msg.sender, 0)) {
                stakedTokenId = tokenOfOwnerByIndex(msg.sender, 0);
            } else {
                stakedTokenId = mint(msg.sender);
            }
        }
        amount = _stake(stakedTokenId);
    }

    /// @inheritdoc IMaverickV2Reward
    function transferAndStake(uint256 tokenId, uint256 _amount) public returns (uint256 amount, uint256 stakedTokenId) {
        stakingToken.safeTransferFrom(msg.sender, address(vault), _amount);
        return stake(tokenId);
    }

    /// @inheritdoc IMaverickV2Reward
    function unstakeToOwner(uint256 tokenId, uint256 amount) public onlyTokenIdAuthorizedUser(tokenId) {
        address owner = ownerOf(tokenId);
        _unstake(tokenId, owner, amount);
    }

    /// @inheritdoc IMaverickV2Reward
    function unstake(uint256 tokenId, address recipient, uint256 amount) public onlyTokenIdAuthorizedUser(tokenId) {
        _unstake(tokenId, recipient, amount);
    }

    /// @inheritdoc IMaverickV2Reward
    function getRewardToOwner(
        uint256 tokenId,
        uint8 rewardTokenIndex,
        uint256 stakeDuration
    ) external onlyTokenIdAuthorizedUser(tokenId) returns (RewardOutput memory) {
        address owner = ownerOf(tokenId);
        return _getReward(tokenId, owner, rewardTokenIndex, stakeDuration, type(uint256).max);
    }

    /// @inheritdoc IMaverickV2Reward
    function getRewardToOwnerForExistingVeLockup(
        uint256 tokenId,
        uint8 rewardTokenIndex,
        uint256 stakeDuration,
        uint256 lockupId
    ) external onlyTokenIdAuthorizedUser(tokenId) returns (RewardOutput memory) {
        address owner = ownerOf(tokenId);
        return _getReward(tokenId, owner, rewardTokenIndex, stakeDuration, lockupId);
    }

    /// @inheritdoc IMaverickV2Reward
    function getReward(
        uint256 tokenId,
        address recipient,
        uint8 rewardTokenIndex,
        uint256 stakeDuration
    ) external onlyTokenIdAuthorizedUser(tokenId) returns (RewardOutput memory) {
        return _getReward(tokenId, recipient, rewardTokenIndex, stakeDuration, type(uint256).max);
    }

    /////////////////////////////////////
    /// Admin Functions
    /////////////////////////////////////

    /// @inheritdoc IMaverickV2Reward
    function pushUnboostedToVe(
        uint8 rewardTokenIndex
    ) public returns (uint128 amount, uint48 timepoint, uint256 batchIndex) {
        IMaverickV2VotingEscrow ve = veTokenByIndex(rewardTokenIndex);
        IERC20 token = rewardTokenByIndex(rewardTokenIndex);
        RewardData storage data = rewardData[rewardTokenIndex];
        amount = data.unboostedAmount;
        if (amount == 0) revert RewardZeroAmount();
        if (block.timestamp <= data.lastUnboostedPushTimestamp + UNBOOSTED_MIN_TIME_GAP) {
            // revert if not enough time has passed; will not revert if this is
            // the first call and last timestamp is zero.
            revert RewardUnboostedTimePeriodNotMet(
                block.timestamp,
                data.lastUnboostedPushTimestamp + UNBOOSTED_MIN_TIME_GAP
            );
        }

        data.unboostedAmount = 0;
        data.lastUnboostedPushTimestamp = block.timestamp;

        token.forceApprove(address(ve), amount);

        timepoint = Time.timestamp();
        batchIndex = ve.createIncentiveBatch(amount, timepoint, ve.MAX_STAKE_DURATION().toUint128(), token);
    }

    /////////////////////////////////////
    /// View Functions
    /////////////////////////////////////

    /// @inheritdoc IMaverickV2Reward
    function rewardInfo() public view returns (RewardInfo[] memory info) {
        uint256 length = rewardTokenCount;
        info = new RewardInfo[](length);
        for (uint8 i; i < length; i++) {
            RewardData storage data = rewardData[i];
            info[i] = RewardInfo({
                finishAt: data.finishAt,
                updatedAt: data.updatedAt,
                rewardRate: data.rewardRate,
                rewardPerTokenStored: data.rewardPerTokenStored,
                rewardToken: rewardTokenByIndex(i),
                veRewardToken: veTokenByIndex(i),
                unboostedAmount: data.unboostedAmount,
                escrowedReward: data.escrowedReward,
                lastUnboostedPushTimestamp: data.lastUnboostedPushTimestamp
            });
        }
    }

    /// @inheritdoc IMaverickV2Reward
    function contractInfo() external view returns (RewardInfo[] memory info, ContractInfo memory _contractInfo) {
        info = rewardInfo();
        _contractInfo.name = name();
        _contractInfo.symbol = symbol();
        _contractInfo.totalSupply = stakeTotalSupply();
        _contractInfo.stakingToken = stakingToken;
    }

    /// @inheritdoc IMaverickV2Reward
    function earned(uint256 tokenId) public view returns (EarnedInfo[] memory earnedInfo) {
        uint256 length = rewardTokenCount;
        earnedInfo = new EarnedInfo[](length);
        for (uint8 i; i < length; i++) {
            RewardData storage data = rewardData[i];
            earnedInfo[i] = EarnedInfo({earned: _earned(tokenId, data), rewardToken: rewardTokenByIndex(i)});
        }
    }

    /// @inheritdoc IMaverickV2Reward
    function earned(uint256 tokenId, IERC20 rewardTokenAddress) public view returns (uint256) {
        uint256 rewardTokenIndex = tokenIndex(rewardTokenAddress);
        RewardData storage data = rewardData[rewardTokenIndex];
        return _earned(tokenId, data);
    }

    function _earned(uint256 tokenId, RewardData storage data) internal view returns (uint256) {
        return
            data.rewards[tokenId] +
            Math.mulFloor(
                stakeBalanceOf(tokenId),
                Math.clip(data.rewardPerTokenStored + _deltaRewardPerToken(data), data.userRewardPerTokenPaid[tokenId])
            );
    }

    /// @inheritdoc IMaverickV2Reward
    function tokenIndex(IERC20 rewardToken) public view returns (uint8 rewardTokenIndex) {
        if (rewardToken == rewardToken0) return 0;
        if (rewardToken == rewardToken1) return 1;
        if (rewardToken == rewardToken2) return 2;
        if (rewardToken == rewardToken3) return 3;
        if (rewardToken == rewardToken4) return 4;
        revert RewardNotValidRewardToken(rewardToken);
    }

    /// @inheritdoc IMaverickV2Reward
    function rewardTokenByIndex(uint8 index) public view returns (IERC20 output) {
        if (index >= rewardTokenCount) revert RewardNotValidIndex(index);
        if (index == 0) return rewardToken0;
        if (index == 1) return rewardToken1;
        if (index == 2) return rewardToken2;
        if (index == 3) return rewardToken3;
        return rewardToken4;
    }

    /// @inheritdoc IMaverickV2Reward
    function veTokenByIndex(uint8 index) public view returns (IMaverickV2VotingEscrow output) {
        if (index >= rewardTokenCount) revert RewardNotValidIndex(index);
        if (index == 0) return veToken0;
        if (index == 1) return veToken1;
        if (index == 2) return veToken2;
        if (index == 3) return veToken3;
        return veToken4;
    }

    /// @inheritdoc IMaverickV2Reward
    function tokenList(bool includeStakingToken) public view returns (IERC20[] memory tokens) {
        uint256 length = includeStakingToken ? rewardTokenCount + 1 : rewardTokenCount;
        tokens = new IERC20[](length);
        if (rewardTokenCount > 0) tokens[0] = rewardToken0;
        if (rewardTokenCount > 1) tokens[1] = rewardToken1;
        if (rewardTokenCount > 2) tokens[2] = rewardToken2;
        if (rewardTokenCount > 3) tokens[3] = rewardToken3;
        if (rewardTokenCount > 4) tokens[4] = rewardToken4;
        if (includeStakingToken) tokens[rewardTokenCount] = stakingToken;
    }

    /**
     * @notice Updates the global reward state for a given reward token.
     * @dev Each time a user stakes or unstakes or a incentivizer adds
     * incentives, this function must be called in order to checkpoint the
     * rewards state before the new stake/unstake/notify occurs.
     */
    function _updateGlobalReward(RewardData storage data) internal {
        uint256 reward = _deltaRewardPerToken(data);
        if (reward != 0) {
            data.rewardPerTokenStored += reward;
            // round up to ensure enough reward is set aside
            data.escrowedReward += Math.mulCeil(reward, stakeTotalSupply()).toUint128();
        }
        data.updatedAt = _lastTimeRewardApplicable(data.finishAt).toUint64();
    }

    /**
     * @notice Updates the reward state associated with an tokenId.  Also
     * updates the global reward state.
     * @dev This function checkpoints the data for a user before they
     * stake/unstake.
     */
    function _updateReward(uint256 tokenId, RewardData storage data) internal {
        _updateGlobalReward(data);
        uint256 reward = _deltaEarned(tokenId, data);
        if (reward != 0) data.rewards[tokenId] += reward.toUint128();
        data.userRewardPerTokenPaid[tokenId] = data.rewardPerTokenStored;
    }

    /**
     * @notice Amount an tokenId has earned since that tokenId last did a
     * stake/unstake.
     * @dev `deltaEarned = balance * (rewardPerToken - userRewardPerTokenPaid)`
     */
    function _deltaEarned(uint256 tokenId, RewardData storage data) internal view returns (uint256) {
        return
            Math.mulFloor(
                stakeBalanceOf(tokenId),
                Math.clip(data.rewardPerTokenStored, data.userRewardPerTokenPaid[tokenId])
            );
    }

    /**
     * @notice Amount of new rewards accrued to tokens since last checkpoint.
     */
    function _deltaRewardPerToken(RewardData storage data) internal view returns (uint256) {
        uint256 timeDiff = Math.clip(_lastTimeRewardApplicable(data.finishAt), data.updatedAt);
        if (timeDiff == 0 || stakeTotalSupply() == 0 || data.rewardRate == 0) {
            return 0;
        }
        return Math.mulDivFloor(data.rewardRate, timeDiff * ONE, stakeTotalSupply());
    }

    /**
     * @notice The smaller of: 1) time of end of reward period and 2) current
     * block timestamp.
     */
    function _lastTimeRewardApplicable(uint256 dataFinishAt) internal view returns (uint256) {
        return Math.min(dataFinishAt, block.timestamp);
    }

    /**
     * @notice Update all rewards.
     */
    function _updateAllRewards(uint256 tokenId) internal {
        for (uint8 i; i < rewardTokenCount; i++) {
            RewardData storage data = rewardData[i];

            _updateReward(tokenId, data);
        }
    }

    /////////////////////////////////////
    /// Internal User Functions
    /////////////////////////////////////

    function _stake(uint256 tokenId) internal nonReentrant returns (uint256 amount) {
        amount = Math.clip(stakingToken.balanceOf(address(vault)), stakeTotalSupply());
        if (amount == 0) revert RewardZeroAmount();
        _requireOwned(tokenId);
        _updateAllRewards(tokenId);
        _mintStake(tokenId, amount);
        emit Stake(msg.sender, tokenId, amount);
    }

    /**
     * @notice Functions using this function must check that sender has access
     * to the tokenId for this to be / safely called.
     */
    function _unstake(uint256 tokenId, address recipient, uint256 amount) internal nonReentrant {
        if (amount == 0) revert RewardZeroAmount();
        _updateAllRewards(tokenId);
        _burnStake(tokenId, amount);
        vault.withdraw(recipient, amount);
        emit UnStake(msg.sender, tokenId, recipient, amount);
    }

    /// @inheritdoc IMaverickV2Reward
    function boostedAmount(
        uint256 tokenId,
        IMaverickV2VotingEscrow veToken,
        uint256 rawAmount,
        uint256 stakeDuration
    ) public view returns (uint256 earnedAmount, bool asVe) {
        if (address(veToken) != address(0)) {
            address owner = ownerOf(tokenId);
            uint256 userVeProRata = Math.divFloor(veToken.balanceOf(owner), veToken.totalSupply());
            uint256 userRewardProRata = Math.divFloor(stakeBalanceOf(tokenId), stakeTotalSupply());
            // pro rata ratio can be bigger than one: need min operation
            uint256 proRataFactor = Math.min(
                ONE,
                BASE_PRORATA_FACTOR + Math.mulDivFloor(PRORATA_FACTOR_SLOPE, userVeProRata, userRewardProRata)
            );
            uint256 stakeFactor = Math.min(
                ONE,
                BASE_STAKING_FACTOR + Math.mulDivFloor(STAKING_FACTOR_SLOPE, stakeDuration, FOUR_YEARS)
            );

            earnedAmount = Math.mulFloor(Math.mulFloor(rawAmount, stakeFactor), proRataFactor);
            // if duration is non-zero, this reward is collected as ve
            asVe = stakeDuration > 0;
        } else {
            earnedAmount = rawAmount;
        }
    }

    /**
     * @notice Internal function for computing the boost and then
     * transferring/staking the resulting rewards.  Can not be safely called
     * without checking that the caller has permissions to access the tokenId.
     */
    function _boostAndPay(
        uint256 tokenId,
        address recipient,
        IERC20 rewardToken,
        IMaverickV2VotingEscrow veToken,
        uint256 rawAmount,
        uint256 stakeDuration,
        uint256 lockupId
    ) internal returns (RewardOutput memory rewardOutput) {
        (rewardOutput.amount, rewardOutput.asVe) = boostedAmount(tokenId, veToken, rawAmount, stakeDuration);
        if (rewardOutput.asVe) {
            rewardToken.forceApprove(address(veToken), rewardOutput.amount);
            rewardOutput.veContract = veToken;
            if (lockupId == type(uint256).max) {
                veToken.stake(rewardOutput.amount.toUint128(), stakeDuration, recipient);
            } else {
                veToken.extendForAccount(recipient, lockupId, stakeDuration, rewardOutput.amount.toUint128());
            }
        } else {
            rewardToken.safeTransfer(recipient, rewardOutput.amount);
        }
    }

    /**
     * @notice Internal getReward function.  Can not be safely called without
     * checking that the caller has permissions to access the account.
     */
    function _getReward(
        uint256 tokenId,
        address recipient,
        uint8 rewardTokenIndex,
        uint256 stakeDuration,
        uint256 lockupId
    ) internal nonReentrant returns (RewardOutput memory rewardOutput) {
        RewardData storage data = rewardData[rewardTokenIndex];
        _updateReward(tokenId, data);
        uint128 reward = data.rewards[tokenId];
        if (reward != 0) {
            data.rewards[tokenId] = 0;
            data.escrowedReward -= reward;
            rewardOutput = _boostAndPay(
                tokenId,
                recipient,
                rewardTokenByIndex(rewardTokenIndex),
                veTokenByIndex(rewardTokenIndex),
                reward,
                stakeDuration,
                lockupId
            );
            if (reward > rewardOutput.amount) {
                // set aside unboosted amount; unsafe cast is okay given conditional
                data.unboostedAmount += uint128(reward - rewardOutput.amount);
            }
            emit GetReward(
                msg.sender,
                tokenId,
                recipient,
                rewardTokenIndex,
                stakeDuration,
                rewardTokenByIndex(rewardTokenIndex),
                rewardOutput,
                lockupId
            );
        }
    }

    /////////////////////////////////////
    /// Add Reward
    /////////////////////////////////////

    /// @inheritdoc IMaverickV2Reward
    function notifyRewardAmount(IERC20 rewardToken, uint256 duration) public nonReentrant returns (uint256) {
        if (duration < MIN_DURATION) revert RewardDurationOutOfBounds(duration, MIN_DURATION, MAX_DURATION);
        if (duration > MAX_DURATION) revert RewardDurationOutOfBounds(duration, MIN_DURATION, MAX_DURATION);
        return _notifyRewardAmount(rewardToken, duration);
    }

    /// @inheritdoc IMaverickV2Reward
    function transferAndNotifyRewardAmount(
        IERC20 rewardToken,
        uint256 duration,
        uint256 amount
    ) public returns (uint256) {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        return notifyRewardAmount(rewardToken, duration);
    }

    /**
     * @notice Called by reward depositor to recompute the reward rate.  If
     * notifier sends more than remaining amount, then notifier sets the rate.
     * Else, we extend the duration at the current rate.
     */
    function _notifyRewardAmount(IERC20 rewardToken, uint256 duration) internal returns (uint256) {
        uint8 rewardTokenIndex = tokenIndex(rewardToken);
        RewardData storage data = rewardData[rewardTokenIndex];
        _updateGlobalReward(data);
        uint256 remainingRewards = Math.clip(
            rewardTokenByIndex(rewardTokenIndex).balanceOf(address(this)),
            data.escrowedReward
        );
        uint256 timeRemaining = Math.clip(data.finishAt, block.timestamp);

        // timeRemaining * data.rewardRate is the amount of rewards on the
        // contract before the new amount was added. we are checking to see if
        // the reamaining rewards is bigger than twice this value.  in this
        // case, the new notifier has brought more rewards than were already on
        // contract and they get to set the new rewards rate.
        if (remainingRewards > timeRemaining * data.rewardRate * 2 || data.rewardRate == 0) {
            // if notifying new amount is bigger than, notifier gets to set the rate
            data.rewardRate = (remainingRewards / duration).toUint128();
        } else {
            // if notifier doesn't bring enough, we extend the duration at the
            // same rate
            duration = remainingRewards / data.rewardRate;
        }

        data.finishAt = (block.timestamp + duration).toUint64();
        // unsafe case is ok given safe cast in previous statement
        data.updatedAt = uint64(block.timestamp);
        emit NotifyRewardAmount(msg.sender, rewardToken, remainingRewards, duration, data.rewardRate);
        return duration;
    }

    /////////////////////////////////////
    /// Required Overrides
    /////////////////////////////////////

    function tokenURI(uint256) public view virtual override(Nft, INft) returns (string memory) {
        /* solhint-disable quotes */
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '","image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAwIiBoZWlnaHQ9IjEyMDAiIHZpZXdCb3g9IjAgMCAxMDAwIDEyMDAiIGZpbGw9Im5vbmUiPgo8cGF0aCBkPSJNMCA1MEMwIDIyLjM4NTggMjIuMzg1OCAwIDUwIDBINjUwQzg0My4zIDAgMTAwMCAxNTYuNyAxMDAwIDM1MFYxMTUwQzEwMDAgMTE3Ny42MSA5NzcuNjE0IDEyMDAgOTUwIDEyMDBIMzUwQzE1Ni43IDEyMDAgMCAxMDQzLjMgMCA4NTBWNTBaIiBmaWxsPSJibGFjayIgZmlsbC1vcGFjaXR5PSIwLjk2Ii8+CjxwYXRoIGQ9Ik04OC40MTA2IDk4LjI1NDRWODRMNTAgMTA0SDEyMS4zMDRWNjRMODguNDEwNiA5OC4yNTQ0WiIgZmlsbD0id2hpdGUiLz4KPHRleHQgeD0iNTAiIHk9IjI1MCIgZm9udC1zaXplPSIzOCIgZmlsbD0icmdiKDI1NSwgMjU1LCAyNTUpIiBsZXR0ZXItc3BhY2luZz0iMiIgZm9udC1mYW1pbHk9IidDb3VyaWVyIE5ldycsIG1vbm9zcGFjZSI+TWF2ZXJpY2sgUmV3YXJkIFBvc2l0aW9uPC90ZXh0Pjwvc3ZnPg==","description":"',
                            name(),
                            '"}'
                        )
                    )
                )
            );
        /* solhint-enable quotes */
    }

    function name() public view override(INft, Nft) returns (string memory) {
        return super.name();
    }

    function symbol() public view override(INft, Nft) returns (string memory) {
        return super.symbol();
    }
}
