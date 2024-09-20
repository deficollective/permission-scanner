// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2BoostedPositionFactory} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPositionFactory.sol";
import {IMaverickV2BoostedPosition} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPosition.sol";

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {IMaverickV2VotingEscrowFactory} from "./interfaces/IMaverickV2VotingEscrowFactory.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2Reward} from "./interfaces/IMaverickV2Reward.sol";
import {RewardDeployer} from "./libraries/RewardDeployer.sol";
import {IMaverickV2RewardFactory} from "./interfaces/IMaverickV2RewardFactory.sol";

/**
 * @notice Reward contract factory that facilitates rewarding stakers in
 * BoostedPositions.
 */
contract MaverickV2RewardFactory is IMaverickV2RewardFactory {
    /// @inheritdoc IMaverickV2RewardFactory
    IMaverickV2BoostedPositionFactory public immutable boostedPositionFactory;
    /// @inheritdoc IMaverickV2RewardFactory
    IMaverickV2VotingEscrowFactory public immutable votingEscrowFactory;
    /// @inheritdoc IMaverickV2RewardFactory
    mapping(IMaverickV2Reward => bool) public isFactoryContract;
    mapping(IERC20 stakeToken => IMaverickV2Reward[]) private _rewardsForStakeToken;
    IMaverickV2Reward[] private _allRewards;
    IMaverickV2Reward[] private _boostedPositionRewards;
    IMaverickV2Reward[] private _nonBoostedPositionRewards;

    constructor(
        IMaverickV2BoostedPositionFactory boostedPositionFactory_,
        IMaverickV2VotingEscrowFactory votingEscrowFactory_
    ) {
        boostedPositionFactory = boostedPositionFactory_;
        votingEscrowFactory = votingEscrowFactory_;
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function createRewardsContract(
        IERC20 stakeToken,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    ) public returns (IMaverickV2Reward rewardsContract) {
        uint256 length = rewardTokens.length;
        if (length > 5) revert RewardFactoryTooManyRewardTokens();
        if (length != veTokens.length) revert RewardFactoryRewardAndVeLengthsAreNotEqual();
        for (uint256 k; k < length; k++) {
            _checkRewards(rewardTokens[k], veTokens[k]);
        }

        uint256 rewardCount = _rewardsForStakeToken[stakeToken].length + 1;
        string memory suffix = string.concat("-R", Strings.toString(rewardCount));

        string memory name = string.concat(IERC20Metadata(address(stakeToken)).name(), suffix);
        string memory symbol = string.concat(IERC20Metadata(address(stakeToken)).symbol(), suffix);

        rewardsContract = RewardDeployer.deploy(name, symbol, stakeToken, rewardTokens, veTokens);

        isFactoryContract[rewardsContract] = true;
        _rewardsForStakeToken[stakeToken].push(rewardsContract);
        _allRewards.push(rewardsContract);

        bool isFactoryBoostedPosition = boostedPositionFactory.isFactoryBoostedPosition(
            IMaverickV2BoostedPosition(address(stakeToken))
        );
        if (isFactoryBoostedPosition) {
            _boostedPositionRewards.push(rewardsContract);
        } else {
            _nonBoostedPositionRewards.push(rewardsContract);
        }

        emit CreateRewardsContract(stakeToken, rewardTokens, veTokens, rewardsContract, isFactoryBoostedPosition);
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function rewardsForStakeToken(
        IERC20 stakeToken,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory) {
        return _slice(_rewardsForStakeToken[stakeToken], startIndex, endIndex);
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function rewardsForStakeTokenCount(IERC20 stakeToken) external view returns (uint256 count) {
        count = _rewardsForStakeToken[stakeToken].length;
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function rewards(uint256 startIndex, uint256 endIndex) external view returns (IMaverickV2Reward[] memory) {
        return _slice(_allRewards, startIndex, endIndex);
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function rewardsCount() external view returns (uint256 count) {
        count = _allRewards.length;
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function boostedPositionRewards(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory) {
        return _slice(_boostedPositionRewards, startIndex, endIndex);
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function boostedPositionRewardsCount() external view returns (uint256 count) {
        count = _boostedPositionRewards.length;
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function nonBoostedPositionRewards(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory) {
        return _slice(_nonBoostedPositionRewards, startIndex, endIndex);
    }

    /// @inheritdoc IMaverickV2RewardFactory
    function nonBoostedPositionRewardsCount() external view returns (uint256 count) {
        count = _nonBoostedPositionRewards.length;
    }

    function _checkRewards(IERC20 rewardToken, IMaverickV2VotingEscrow veToken) internal view {
        if (address(veToken) != address(0)) {
            // if ve is specified, then it must be a factory ve token.
            // rewardToken must be baseToken of ve; check by computing ve
            // address from factory deploy
            if (votingEscrowFactory.veForBaseToken(rewardToken) != veToken)
                revert RewardFactoryInvalidVeBaseTokenPair();
        }
    }

    function _slice(
        IMaverickV2Reward[] storage _rewards,
        uint256 startIndex,
        uint256 endIndex
    ) internal view returns (IMaverickV2Reward[] memory returnElements) {
        endIndex = Math.min(_rewards.length, endIndex);
        returnElements = new IMaverickV2Reward[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                returnElements[i - startIndex] = _rewards[i];
            }
        }
    }
}
