// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {INft} from "@maverick/v2-supplemental/contracts/positionbase/INft.sol";
import {IMulticall} from "@maverick/v2-common/contracts/base/IMulticall.sol";

import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";
import {IMaverickV2RewardVault} from "./IMaverickV2RewardVault.sol";
import {IRewardAccounting} from "../rewardbase/IRewardAccounting.sol";

interface IMaverickV2Reward is INft, IMulticall, IRewardAccounting {
    event NotifyRewardAmount(
        address sender,
        IERC20 rewardTokenAddress,
        uint256 amount,
        uint256 duration,
        uint256 rewardRate
    );
    event GetReward(
        address sender,
        uint256 tokenId,
        address recipient,
        uint8 rewardTokenIndex,
        uint256 stakeDuration,
        IERC20 rewardTokenAddress,
        RewardOutput rewardOutput,
        uint256 lockupId
    );
    event UnStake(
        address sender,
        uint256 tokenId,
        uint256 amount,
        address recipient,
        uint256 userBalance,
        uint256 totalSupply
    );
    event Stake(
        address sender,
        address supplier,
        uint256 amount,
        uint256 tokenId,
        uint256 userBalance,
        uint256 totalSupply
    );
    event AddRewardToken(IERC20 rewardTokenAddress, uint8 rewardTokenIndex);
    event RemoveRewardToken(IERC20 rewardTokenAddress, uint8 rewardTokenIndex);
    event ApproveRewardGetter(uint256 tokenId, address getter);

    error RewardDurationOutOfBounds(uint256 duration, uint256 minDuration, uint256 maxDuration);
    error RewardZeroAmount();
    error RewardNotValidRewardToken(IERC20 rewardTokenAddress);
    error RewardNotValidIndex(uint8 index);
    error RewardTokenCannotBeStakingToken(IERC20 stakingToken);
    error RewardTransferNotSupported();
    error RewardNotApprovedGetter(uint256 tokenId, address approved, address getter);
    error RewardUnboostedTimePeriodNotMet(uint256 timestamp, uint256 minTimestamp);

    struct RewardInfo {
        // Timestamp of when the rewards finish
        uint256 finishAt;
        // Minimum of last updated time and reward finish time
        uint256 updatedAt;
        // Reward to be paid out per second
        uint256 rewardRate;
        // Escrowed rewards
        uint256 escrowedReward;
        // Sum of (reward rate * dt * 1e18 / total supply)
        uint256 rewardPerTokenStored;
        // Reward Token to be emitted
        IERC20 rewardToken;
        // ve locking contract
        IMaverickV2VotingEscrow veRewardToken;
        // amount available to push to ve as incentive
        uint128 unboostedAmount;
        // timestamp of unboosted push
        uint256 lastUnboostedPushTimestamp;
    }

    struct ContractInfo {
        // Reward Name
        string name;
        // Reward Symbol
        string symbol;
        // total supply staked
        uint256 totalSupply;
        // staking token
        IERC20 stakingToken;
    }

    struct EarnedInfo {
        // earned
        uint256 earned;
        // reward token
        IERC20 rewardToken;
    }

    struct RewardOutput {
        uint256 amount;
        bool asVe;
        IMaverickV2VotingEscrow veContract;
    }

    // solhint-disable-next-line func-name-mixedcase
    function MAX_DURATION() external view returns (uint256);

    // solhint-disable-next-line func-name-mixedcase
    function MIN_DURATION() external view returns (uint256);

    /**
     * @notice This function retrieves the minimum time gap in seconds that
     * must have elasped between calls to `pushUnboostedToVe()`.
     */
    // solhint-disable-next-line func-name-mixedcase
    function UNBOOSTED_MIN_TIME_GAP() external view returns (uint256);

    /**
     * @notice This function retrieves the address of the token used for
     * staking in this reward contract.
     * @return The address of the staking token (IERC20).
     */
    function stakingToken() external view returns (IERC20);

    /**
     * @notice This function retrieves the address of the MaverickV2RewardVault
     * contract associated with this reward contract.
     * @return The address of the IMaverickV2RewardVault contract.
     */
    function vault() external view returns (IMaverickV2RewardVault);

    /**
     * @notice This function retrieves information about all available reward tokens for this reward contract.
     * @return info An array of RewardInfo structs containing details about each reward token.
     */
    function rewardInfo() external view returns (RewardInfo[] memory info);

    /**
     * @notice This function retrieves information about all available reward
     * tokens and overall contract details for this reward contract.
     * @return info An array of RewardInfo structs containing details about each reward token.
     * @return _contractInfo A ContractInfo struct containing overall contract details.
     */
    function contractInfo() external view returns (RewardInfo[] memory info, ContractInfo memory _contractInfo);

    /**
     * @notice This function calculates the total amount of all earned rewards
     * for a specific tokenId across all reward tokens.
     * @param tokenId The address of the tokenId for which to calculate earned rewards.
     * @return earnedInfo An array of EarnedInfo structs containing details about earned rewards for each supported token.
     */
    function earned(uint256 tokenId) external view returns (EarnedInfo[] memory earnedInfo);

    /**
     * @notice This function calculates the total amount of earned rewards for
     * a specific tokenId for a particular reward token.
     * @param tokenId The address of the tokenId for which to calculate earned rewards.
     * @param rewardTokenAddress The address of the specific reward token.
     * @return amount The total amount of earned rewards for the specified token.
     */
    function earned(uint256 tokenId, IERC20 rewardTokenAddress) external view returns (uint256);

    /**
     * @notice This function retrieves the internal index associated with a specific reward token address.
     * @param  rewardToken The address of the reward token to get the index for.
     * @return rewardTokenIndex The internal index of the token within the reward contract (uint8).
     */
    function tokenIndex(IERC20 rewardToken) external view returns (uint8 rewardTokenIndex);

    /**
     * @notice This function retrieves the total number of supported reward tokens in this reward contract.
     * @return count The total number of reward tokens (uint256).
     */
    function rewardTokenCount() external view returns (uint256);

    /**
     * @notice This function transfers a specified amount of reward tokens from
     * the caller to distribute them over a defined duration. The caller will
     * need to approve this rewards contract to make the transfer on the
     * caller's behalf. See `notifyRewardAmount` for details of how the
     * duration is set by the rewards contract.
     * @param rewardToken The address of the reward token to transfer.
     * @param duration The duration (in seconds) over which to distribute the rewards.
     * @param amount The amount of reward tokens to transfer.
     * @return _duration The duration in seconds that the incentives will be distributed over.
     */
    function transferAndNotifyRewardAmount(
        IERC20 rewardToken,
        uint256 duration,
        uint256 amount
    ) external returns (uint256 _duration);

    /**
     * @notice This function notifies the vault to distribute a previously
     * transferred amount of reward tokens over a defined duration. (Assumes
     * tokens are already in the contract).
     * @dev The duration of the distribution may not be the same as the input
     * duration.  If this notify amount is less than the amount already pending
     * disbursement, then this new amount will be distributed as the same rate
     * as the existing rate and that will dictate the duration.  Alternatively,
     * if the amount is more than the pending disbursement, then the input
     * duration will be honored and all pending disbursement tokens will also be
     * distributed at this newly set rate.
     * @param rewardToken The address of the reward token to distribute.
     * @param duration The duration (in seconds) over which to distribute the rewards.
     * @return _duration The duration in seconds that the incentives will be distributed over.
     */
    function notifyRewardAmount(IERC20 rewardToken, uint256 duration) external returns (uint256 _duration);

    /**
     * @notice This function transfers a specified amount of staking tokens
     * from the caller to the staking `vault()` and stakes them on the
     * recipient's behalf.  The user has to approve this reward contract to
     * transfer the staking token on their behalf for this function not to
     * revert.
     * @param tokenId Nft tokenId to stake for the staked tokens.
     * @param _amount The amount of staking tokens to transfer and stake.
     * @return amount The amount of staking tokens staked.  May differ from
     * input if there were unstaked tokens in the vault prior to this call.
     * @return stakedTokenId TokenId where liquidity was staked to.  This may
     * differ from the input tokenIf if the input `tokenId=0`.
     */
    function transferAndStake(
        uint256 tokenId,
        uint256 _amount
    ) external returns (uint256 amount, uint256 stakedTokenId);

    /**
     * @notice This function stakes the staking tokens to the specified
     * tokenId. If `tokenId=0` is passed in, then this function will look up
     * the caller's tokenIds and stake to the zero-index tokenId.  If the user
     * does not yet have a staking NFT tokenId, this function will mint one for
     * the sender and stake to that newly-minted tokenId.
     *
     * @dev The amount staked is derived by looking at the new balance on
     * the `vault()`. So, for staking to yield a non-zero balance, the user
     * will need to have transfered the `stakingToken()` to the `vault()` prior
     * to calling `stake`.  Note, tokens sent to the reward contract instead
     * of the vault will not be stakable and instead will be eligible to be
     * disbursed as rewards to stakers.  This is an advanced usage function.
     * If in doubt about the mechanics of staking, use `transferAndStake()`
     * instead.
     * @param tokenId The address of the tokenId whose tokens to stake.
     * @return amount The amount of staking tokens staked (uint256).
     * @return stakedTokenId TokenId where liquidity was staked to.  This may
     * differ from the input tokenIf if the input `tokenId=0`.
     */
    function stake(uint256 tokenId) external returns (uint256 amount, uint256 stakedTokenId);

    /**
     * @notice This function initiates unstaking of a specified amount of
     * staking tokens for the caller and sends them to a recipient.
     * @param tokenId The address of the tokenId whose tokens to unstake.
     * @param amount The amount of staking tokens to unstake (uint256).
     */
    function unstakeToOwner(uint256 tokenId, uint256 amount) external;

    /**
     * @notice This function initiates unstaking of a specified amount of
     * staking tokens on behalf of a specific tokenId and sends them to a recipient.
     * @dev To unstakeFrom, the caller must have an approval allowance of at
     * least `amount`.  Approvals follow the ERC-721 approval interface.
     * @param tokenId The address of the tokenId whose tokens to unstake.
     * @param recipient The address to which the unstaked tokens will be sent.
     * @param amount The amount of staking tokens to unstake (uint256).
     */
    function unstake(uint256 tokenId, address recipient, uint256 amount) external;

    /**
     * @notice This function retrieves the claimable reward for a specific
     * reward token and stake duration for the caller.
     * @param tokenId The address of the tokenId whose reward to claim.
     * @param rewardTokenIndex The internal index of the reward token.
     * @param stakeDuration The duration (in seconds) for which the rewards were staked.
     * @return rewardOutput A RewardOutput struct containing details about the claimable reward.
     */
    function getRewardToOwner(
        uint256 tokenId,
        uint8 rewardTokenIndex,
        uint256 stakeDuration
    ) external returns (RewardOutput memory rewardOutput);

    /**
     * @notice This function retrieves the claimable reward for a specific
     * reward token, stake duration, and lockup ID for the caller.
     * @param tokenId The address of the tokenId whose reward to claim.
     * @param rewardTokenIndex The internal index of the reward token.
     * @param stakeDuration The duration (in seconds) for which the rewards were staked.
     * @param lockupId The unique identifier for the specific lockup (optional).
     * @return rewardOutput A RewardOutput struct containing details about the claimable reward.
     */
    function getRewardToOwnerForExistingVeLockup(
        uint256 tokenId,
        uint8 rewardTokenIndex,
        uint256 stakeDuration,
        uint256 lockupId
    ) external returns (RewardOutput memory);

    /**
     * @notice This function retrieves the claimable reward for a specific
     * reward token and stake duration for a specified tokenId and sends it to
     * a recipient.  If the reward is staked in the corresponding veToken, a
     * new lockup in the ve token will be created.
     * @param tokenId The address of the tokenId whose reward to claim.
     * @param recipient The address to which the claimed reward will be sent.
     * @param rewardTokenIndex The internal index of the reward token.
     * @param stakeDuration The duration (in seconds) for which the rewards
     * will be staked in the ve contract.
     * @return rewardOutput A RewardOutput struct containing details about the claimable reward.
     */
    function getReward(
        uint256 tokenId,
        address recipient,
        uint8 rewardTokenIndex,
        uint256 stakeDuration
    ) external returns (RewardOutput memory);

    /**
     * @notice This function retrieves a list of all supported tokens in the reward contract.
     * @param includeStakingToken A flag indicating whether to include the staking token in the list.
     * @return tokens An array of IERC20 token addresses.
     */
    function tokenList(bool includeStakingToken) external view returns (IERC20[] memory tokens);

    /**
     * @notice This function retrieves the veToken contract associated with a
     * specific index within the reward contract.
     * @param index The index of the veToken to retrieve.
     * @return output The IMaverickV2VotingEscrow contract associated with the index.
     */
    function veTokenByIndex(uint8 index) external view returns (IMaverickV2VotingEscrow output);

    /**
     * @notice This function retrieves the reward token contract associated
     * with a specific index within the reward contract.
     * @param index The index of the reward token to retrieve.
     * @return output The IERC20 contract associated with the index.
     */
    function rewardTokenByIndex(uint8 index) external view returns (IERC20 output);

    /**
     * @notice This function calculates the boosted amount an tokenId would
     * receive based on their veToken balance and stake duration.
     * @param tokenId The address of the tokenId for which to calculate the boosted amount.
     * @param veToken The IMaverickV2VotingEscrow contract representing the veToken used for boosting.
     * @param rawAmount The raw (unboosted) amount.
     * @param stakeDuration The duration (in seconds) for which the rewards would be staked.
     * @return earnedAmount The boosted amount the tokenId would receive (uint256).
     * @return asVe A boolean indicating whether the boosted amount is
     * staked in the veToken (true) or is disbursed without ve staking required (false).
     */
    function boostedAmount(
        uint256 tokenId,
        IMaverickV2VotingEscrow veToken,
        uint256 rawAmount,
        uint256 stakeDuration
    ) external view returns (uint256 earnedAmount, bool asVe);

    /**
     * @notice This function is used to push unboosted rewards to the veToken
     * contract.  This unboosted reward amount is then distributed to the
     * veToken holders. This function will revert if less than
     * `UNBOOSTED_MIN_TIME_GAP()` seconds have passed since the last call.
     * @param rewardTokenIndex The internal index of the reward token.
     * @return amount The amount of unboosted rewards pushed (uint128).
     * @return timepoint The timestamp associated with the pushed rewards (uint48).
     * @return batchIndex The batch index for the pushed rewards (uint256).
     */
    function pushUnboostedToVe(
        uint8 rewardTokenIndex
    ) external returns (uint128 amount, uint48 timepoint, uint256 batchIndex);

    /**
     * @notice Mints an NFT stake to a user.  This NFT will not possesses any
     * assets until a user `stake`s asset to the NFT tokenId as part of a
     * separate call.
     * @param recipient The address that owns the output NFT
     */
    function mint(address recipient) external returns (uint256 tokenId);

    /**
     * @notice Mints an NFT stake to caller.  This NFT will not possesses any
     * assets until a user `stake`s asset to the NFT tokenId as part of a
     * separate call.
     */
    function mintToSender() external returns (uint256 tokenId);
}
