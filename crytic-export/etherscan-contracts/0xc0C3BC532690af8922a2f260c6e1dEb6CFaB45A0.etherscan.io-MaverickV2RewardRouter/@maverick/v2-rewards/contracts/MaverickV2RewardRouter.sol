// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";

import {MaverickV2LiquidityManager} from "@maverick/v2-supplemental/contracts/MaverickV2LiquidityManager.sol";
import {IMaverickV2PoolLens} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2PoolLens.sol";
import {IMaverickV2BoostedPosition} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPosition.sol";
import {IWETH9} from "@maverick/v2-supplemental/contracts/paymentbase/IWETH9.sol";
import {IMaverickV2Position} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2Position.sol";
import {IMaverickV2BoostedPositionFactory} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPositionFactory.sol";

import {IMaverickV2Reward} from "./interfaces/IMaverickV2Reward.sol";
import {IMaverickV2RewardRouter} from "./interfaces/IMaverickV2RewardRouter.sol";
import {IMaverickV2RewardFactory} from "./interfaces/IMaverickV2RewardFactory.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2VotingEscrowWSync} from "./interfaces/IMaverickV2VotingEscrowWSync.sol";

/**
 * @notice Liquidity and Reward contract to facilitate multi-step interactions
 * with adding and staking liquidity in Maverick V2.  This contracts inherits
 * all of the functionality of `MaverickV2LiquidityManager` that allows the
 * creation of pools and BPs and adds mechanisms to interact with the various
 * reward and ve functionality that are present in v2-rewards.  All of the
 * functions are specified as `payable` to enable multicall transactions that
 * involve functions that require ETH and those that do not.
 */
contract MaverickV2RewardRouter is IMaverickV2RewardRouter, MaverickV2LiquidityManager {
    using SafeERC20 for IERC20;

    /// @inheritdoc IMaverickV2RewardRouter
    IMaverickV2RewardFactory public immutable rewardFactory;

    constructor(
        IMaverickV2Factory _factory,
        IWETH9 _weth,
        IMaverickV2Position _position,
        IMaverickV2BoostedPositionFactory _boostedPositionFactory,
        IMaverickV2RewardFactory _rewardFactory
    ) MaverickV2LiquidityManager(_factory, _weth, _position, _boostedPositionFactory) {
        rewardFactory = _rewardFactory;
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function stake(
        IMaverickV2Reward reward,
        uint256 tokenId
    ) public payable returns (uint256 amount, uint256 stakedTokenId) {
        stakedTokenId = tokenId;
        if (stakedTokenId == 0) {
            if (reward.tokenOfOwnerByIndexExists(msg.sender, 0)) {
                stakedTokenId = reward.tokenOfOwnerByIndex(msg.sender, 0);
            } else {
                stakedTokenId = reward.mint(msg.sender);
            }
        }
        return reward.stake(stakedTokenId);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function transferAndStake(
        IMaverickV2Reward reward,
        uint256 tokenId,
        uint256 _amount
    ) public payable returns (uint256 amount, uint256 stakedTokenId) {
        reward.stakingToken().safeTransferFrom(msg.sender, address(reward.vault()), _amount);
        return stake(reward, tokenId);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function notifyRewardAmount(
        IMaverickV2Reward reward,
        IERC20 rewardToken,
        uint256 duration
    ) public payable returns (uint256 _duration) {
        return reward.notifyRewardAmount(rewardToken, duration);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function transferAndNotifyRewardAmount(
        IMaverickV2Reward reward,
        IERC20 rewardToken,
        uint256 duration,
        uint256 amount
    ) public payable returns (uint256 _duration) {
        rewardToken.safeTransferFrom(msg.sender, address(reward), amount);
        return reward.notifyRewardAmount(rewardToken, duration);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function createBoostedPositionAndAddLiquidityAndStake(
        address recipient,
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    )
        public
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            IMaverickV2Reward reward,
            uint256 tokenId
        )
    {
        (boostedPosition, mintedLpAmount, tokenAAmount, tokenBAmount) = createBoostedPositionAndAddLiquidity(
            address(this),
            params
        );
        reward = rewardFactory.createRewardsContract(boostedPosition, rewardTokens, veTokens);
        tokenId = reward.mint(recipient);
        boostedPosition.transfer(address(reward.vault()), boostedPosition.balanceOf(address(this)));
        (stakeAmount, ) = reward.stake(tokenId);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function createBoostedPositionAndAddLiquidityAndStakeToSender(
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    )
        public
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            IMaverickV2Reward reward,
            uint256 tokenId
        )
    {
        return createBoostedPositionAndAddLiquidityAndStake(msg.sender, params, rewardTokens, veTokens);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function addLiquidityAndMintBoostedPositionAndStake(
        uint256 tokenId,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs,
        IMaverickV2Reward reward
    ) public payable returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount, uint256 stakeAmount) {
        (mintedLpAmount, tokenAAmount, tokenBAmount) = addLiquidityAndMintBoostedPosition(
            address(reward.vault()),
            boostedPosition,
            packedSqrtPriceBreaks,
            packedArgs
        );
        (stakeAmount, ) = reward.stake(tokenId);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function addLiquidityAndMintBoostedPositionAndStakeToSender(
        uint256 sendersTokenIndex,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs,
        IMaverickV2Reward reward
    )
        public
        payable
        returns (
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint256 stakeAmount,
            uint256 tokenId
        )
    {
        if (reward.tokenOfOwnerByIndexExists(msg.sender, sendersTokenIndex)) {
            tokenId = reward.tokenOfOwnerByIndex(msg.sender, sendersTokenIndex);
        } else {
            tokenId = reward.mint(msg.sender);
        }

        (mintedLpAmount, tokenAAmount, tokenBAmount, stakeAmount) = addLiquidityAndMintBoostedPositionAndStake(
            tokenId,
            boostedPosition,
            packedSqrtPriceBreaks,
            packedArgs,
            reward
        );
    }

    function mintTokenInRewardToSender(IMaverickV2Reward reward) public payable returns (uint256 tokenId) {
        tokenId = reward.mint(msg.sender);
    }

    function mintTokenInReward(IMaverickV2Reward reward, address recipient) public payable returns (uint256 tokenId) {
        tokenId = reward.mint(recipient);
    }

    /// @inheritdoc IMaverickV2RewardRouter
    function sync(
        IMaverickV2VotingEscrowWSync ve,
        address staker,
        uint256[] memory legacyLockupIndexes
    ) public returns (uint256[] memory newBalance) {
        uint256 length = legacyLockupIndexes.length;
        newBalance = new uint256[](length);
        for (uint256 k; k < length; k++) {
            newBalance[k] = ve.sync(staker, k);
        }
    }
}
