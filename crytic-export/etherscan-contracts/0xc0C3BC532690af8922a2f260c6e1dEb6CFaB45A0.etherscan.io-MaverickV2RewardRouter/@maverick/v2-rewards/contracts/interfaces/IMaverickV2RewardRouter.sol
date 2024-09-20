// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2PoolLens} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2PoolLens.sol";
import {IMaverickV2BoostedPosition} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPosition.sol";
import {IMaverickV2LiquidityManager} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2LiquidityManager.sol";

import {IMaverickV2RewardFactory} from "./IMaverickV2RewardFactory.sol";
import {IMaverickV2VotingEscrowWSync} from "./IMaverickV2VotingEscrowWSync.sol";
import {IMaverickV2Reward} from "./IMaverickV2Reward.sol";
import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";

interface IMaverickV2RewardRouter is IMaverickV2LiquidityManager {
    /**
     * @notice This function stakes any new staking token balance that are in
     * the `reward.vault()` for a specified recipient tokenId.  Passing input
     * `tokenId=0` will cause the stake to mint to either the first tokenId for
     * the caller, or a new NFT tokenId if the sender does not yet have one.
     * @param reward The IMaverickV2Reward contract for which to stake.
     * @param tokenId Nft tokenId to stake for the staked tokens.
     * @return amount The amount of staking tokens staked.  May differ from
     * input if there were unstaked tokens in the vault prior to this call.
     * @return stakedTokenId TokenId where liquidity was staked to.  This may
     * differ from the input tokenId if the input `tokenId=0`.
     */
    function stake(
        IMaverickV2Reward reward,
        uint256 tokenId
    ) external payable returns (uint256 amount, uint256 stakedTokenId);

    /**
     * @notice This function retrieves the address of the MaverickV2RewardFactory
     * contract associated with this contract.
     */
    function rewardFactory() external view returns (IMaverickV2RewardFactory);

    /**
     * @notice This function transfers a specified amount of reward tokens from
     * the caller to a reward contract and notifies it to distribute them over
     * a defined duration.
     * @param reward The IMaverickV2Reward contract to notify.
     * @param rewardToken The address of the reward token to transfer.
     * @param duration The duration (in seconds) over which to distribute the rewards.
     * @return _duration The duration in seconds that the incentives will be distributed over.
     */
    function notifyRewardAmount(
        IMaverickV2Reward reward,
        IERC20 rewardToken,
        uint256 duration
    ) external payable returns (uint256 _duration);

    /**
     * @notice This function transfers a specified amount of staking tokens from
     * the caller, stakes them on the recipient's behalf, and
     * associates them with a specified reward contract.
     * @param reward The IMaverickV2Reward contract for which to stake.
     * @param tokenId Nft tokenId to stake for the staked tokens.
     * @param _amount The amount of staking tokens to transfer and stake.
     * @return amount The amount of staking tokens staked.  May differ from
     * input if there were unstaked tokens in the vault prior to this call.
     * @return stakedTokenId TokenId where liquidity was staked to.  This may
     * differ from the input tokenIf if the input `tokenId=0`.
     *
     */
    function transferAndStake(
        IMaverickV2Reward reward,
        uint256 tokenId,
        uint256 _amount
    ) external payable returns (uint256 amount, uint256 stakedTokenId);

    /**
     * @notice This function transfers a specified amount of reward tokens
     *  from the caller and adds them to the reward contract as incentives.
     * @param reward The IMaverickV2Reward contract to notify.
     * @param rewardToken The address of the reward token to transfer.
     * @param duration The duration (in seconds) over which to distribute the rewards.
     * @param amount The amount of staking tokens to stake (uint256).
     * @return _duration The duration in seconds that the incentives will be distributed over.
     */
    function transferAndNotifyRewardAmount(
        IMaverickV2Reward reward,
        IERC20 rewardToken,
        uint256 duration,
        uint256 amount
    ) external payable returns (uint256 _duration);

    /**
     * @notice This function creates a new BoostedPosition contract, adds
     * liquidity to a pool using the provided parameters, stakes the received
     * LP tokens, and associates them with a specified reward contract.
     * @param recipient The address to which the minted LP tokens will be
     * credited.
     * @param params A struct containing parameters for creating the
     * BoostedPosition (see IMaverickV2PoolLens.CreateBoostedPositionInputs).
     * @param rewardTokens An array of IERC20 token addresses representing the
     * available reward tokens for the staked LP position.
     * @param veTokens An array of IMaverickV2VotingEscrow contract addresses
     * representing the veTokens used for boosting.
     * @return boostedPosition The created IMaverickV2BoostedPosition contract.
     * @return mintedLpAmount The amount of LP tokens minted from the added liquidity.
     * @return tokenAAmount The amount of token A deposited for liquidity.
     * @return tokenBAmount The amount of token B deposited for liquidity.
     * @return stakeAmount The amount of LP tokens staked in the reward contract.
     * @return reward The IMaverickV2Reward contract.
     * @return tokenId Token on reward contract where user liquidity was staked.
     */
    function createBoostedPositionAndAddLiquidityAndStake(
        address recipient,
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    )
        external
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            IMaverickV2Reward reward,
            uint256 tokenId
        );

    /**
     * @notice This function is similar to
     * `createBoostedPositionAndAddLiquidityAndStake` but stakes the minted LP
     * tokens for the caller (msg.sender) instead of a specified recipient.
     * @param params A struct containing parameters for creating the
     * BoostedPosition (see IMaverickV2PoolLens.CreateBoostedPositionInputs).
     * @param rewardTokens An array of IERC20 token addresses representing the
     * available reward tokens for the staked LP position.
     * @param veTokens An array of IMaverickV2VotingEscrow contract addresses
     * representing the veTokens used for boosting.
     * @return boostedPosition The created IMaverickV2BoostedPosition contract.
     * @return mintedLpAmount The amount of LP tokens minted from the added liquidity.
     * @return tokenAAmount The amount of token A deposited for liquidity.
     * @return tokenBAmount The amount of token B deposited for liquidity.
     * @return stakeAmount The amount of LP tokens staked in the reward contract.
     * @return reward The IMaverickV2Reward contract associated with the staked LP position.
     * @return tokenId Token on reward contract where user liquidity was staked.
     */
    function createBoostedPositionAndAddLiquidityAndStakeToSender(
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    )
        external
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            IMaverickV2Reward reward,
            uint256 tokenId
        );

    /**
     * @notice This function adds liquidity to a pool using a pre-created
     * BoostedPosition contract, stakes the received LP tokens, and associates
     * them with a specified reward contract.
     * @param tokenId Token on reward contract where liquidity is to be staked.
     * @param boostedPosition The IMaverickV2BoostedPosition contract representing the existing boosted position.
     * @param packedSqrtPriceBreaks A packed representation of sqrt price
     * breaks for the liquidity range (see
     * IMaverickV2Pool.IAddLiquidityParams).
     * @param packedArgs Additional packed arguments for adding liquidity (see
     * IMaverickV2Pool.IAddLiquidityParams).
     * @param reward The IMaverickV2Reward contract for which to stake the LP tokens.
     * @return mintedLpAmount The amount of LP tokens minted from the added liquidity.
     * @return tokenAAmount The amount of token A deposited for liquidity.
     * @return tokenBAmount The amount of token B deposited for liquidity.
     * @return stakeAmount The amount of LP tokens staked in the reward contract.
     *
     */
    function addLiquidityAndMintBoostedPositionAndStake(
        uint256 tokenId,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs,
        IMaverickV2Reward reward
    )
        external
        payable
        returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount, uint256 stakeAmount);

    /**
     * @notice This function is similar to
     * `addLiquidityAndMintBoostedPositionAndStake` but uses the caller
     * (msg.sender) as the recipient for the minted reward stake.
     * @param sendersTokenIndex Token index of sender on the reward contract to
     * mint to.  If sender does not have a token already, then this call will
     * mint one for the user.
     * @param boostedPosition The IMaverickV2BoostedPosition contract representing the existing boosted position.
     * @param packedSqrtPriceBreaks A packed representation of sqrt price breaks for the liquidity range (see IMaverickV2Pool.IAddLiquidityParams).
     * @param packedArgs Additional packed arguments for adding liquidity (see IMaverickV2Pool.IAddLiquidityParams).
     * @param reward The IMaverickV2Reward contract for which to stake the LP tokens.
     * @return mintedLpAmount The amount of LP tokens minted from the added liquidity.
     * @return tokenAAmount The amount of token A deposited for liquidity.
     * @return tokenBAmount The amount of token B deposited for liquidity.
     * @return stakeAmount The amount of LP tokens staked in the reward contract.
     * @return tokenId Token on reward contract where user liquidity was staked.
     */
    function addLiquidityAndMintBoostedPositionAndStakeToSender(
        uint256 sendersTokenIndex,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs,
        IMaverickV2Reward reward
    )
        external
        payable
        returns (
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            uint256 tokenId
        );

    /**
     * @notice This function syncs the balance of a staker's votes on the
     * legacy ve mav contract with the new V2 ve mav contract.
     * @param ve The IMaverickV2VotingEscrowWSync contract to interact with.
     * @param staker The address of the user whose veToken lock may need syncing.
     * @param  legacyLockupIndexes A list of indexes to synchronize from the
     * legacy veMav to the V2 ve contract.
     *
     */
    function sync(
        IMaverickV2VotingEscrowWSync ve,
        address staker,
        uint256[] memory legacyLockupIndexes
    ) external returns (uint256[] memory newBalance);

    function mintTokenInRewardToSender(IMaverickV2Reward reward) external payable returns (uint256 tokenId);

    function mintTokenInReward(IMaverickV2Reward reward, address recipient) external payable returns (uint256 tokenId);
}
