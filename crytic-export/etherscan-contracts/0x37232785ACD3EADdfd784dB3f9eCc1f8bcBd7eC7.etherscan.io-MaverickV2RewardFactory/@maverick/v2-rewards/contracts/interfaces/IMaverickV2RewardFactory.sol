// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2BoostedPositionFactory} from "@maverick/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPositionFactory.sol";

import {IMaverickV2VotingEscrowFactory} from "./IMaverickV2VotingEscrowFactory.sol";
import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";
import {IMaverickV2Reward} from "./IMaverickV2Reward.sol";

interface IMaverickV2RewardFactory {
    error RewardFactoryNotFactoryBoostedPosition();
    error RewardFactoryTooManyRewardTokens();
    error RewardFactoryRewardAndVeLengthsAreNotEqual();
    error RewardFactoryInvalidVeBaseTokenPair();

    event CreateRewardsContract(
        IERC20 stakeToken,
        IERC20[] rewardTokens,
        IMaverickV2VotingEscrow[] veTokens,
        IMaverickV2Reward rewardsContract,
        bool isFactoryBoostedPosition
    );

    /**
     * @notice This function creates a new MaverickV2Reward contract associated
     * with a specific stake token contract and set of reward and voting
     * escrow tokens.
     * @param stakeToken Token to be staked in reward contract; e.g. a boosted position contract.
     * @param rewardTokens An array of IERC20 token addresses representing the available reward tokens.
     * @param veTokens An array of IMaverickV2VotingEscrow contract addresses
     * representing the associated veTokens for boosting.
     * @return rewardsContract The newly created IMaverickV2Reward contract.
     */
    function createRewardsContract(
        IERC20 stakeToken,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    ) external returns (IMaverickV2Reward rewardsContract);

    /**
     * @notice This function retrieves the address of the MaverickV2BoostedPositionFactory contract.
     * @return factory The address of the IMaverickV2BoostedPositionFactory contract.
     */
    function boostedPositionFactory() external returns (IMaverickV2BoostedPositionFactory);

    /**
     * @notice This function retrieves the address of the MaverickV2VotingEscrowFactory contract.
     * @return factory The address of the IMaverickV2VotingEscrowFactory contract.
     */
    function votingEscrowFactory() external returns (IMaverickV2VotingEscrowFactory);

    /**
     * @notice This function checks if a provided IMaverickV2Reward contract is
     * a valid contract created by this factory.
     * @param reward The IMaverickV2Reward contract to check.
     * @return isFactoryContract True if the contract is a valid factory-created reward contract, False otherwise.
     */
    function isFactoryContract(IMaverickV2Reward reward) external returns (bool);

    /**
     * @notice This function retrieves a list of all MaverickV2Reward contracts
     * associated with a specific staking token contract within a specified
     * range.
     * @param stakeToken Lookup token.
     * @param startIndex The starting index of the list to retrieve.
     * @param endIndex The ending index of the list to retrieve.
     * @return rewardsContract An array of IMaverickV2Reward contracts
     * associated with the BoostedPosition within the specified range.
     */
    function rewardsForStakeToken(
        IERC20 stakeToken,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory rewardsContract);

    /**
     * @notice Returns the number of reward contracts this factory has deployed
     * for a given staking token.
     */
    function rewardsForStakeTokenCount(IERC20 stakeToken) external view returns (uint256 count);

    /**
     * @notice This function retrieves a list of all MaverickV2Reward contracts within a specified range.
     * @param startIndex The starting index of the list to retrieve.
     * @param endIndex The ending index of the list to retrieve.
     * @return rewardsContract An array of IMaverickV2Reward contracts within the specified range.
     */
    function rewards(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory rewardsContract);

    /**
     * @notice Returns the number of reward contracts this factory has deployed.
     */
    function rewardsCount() external view returns (uint256 count);

    /**
     * @notice This function retrieves a list of all MaverickV2Reward contracts
     * within a specified range that have a staking token that is a boosted
     * position from the maverick boosted position contract.
     * @param startIndex The starting index of the list to retrieve.
     * @param endIndex The ending index of the list to retrieve.
     * @return rewardsContract An array of IMaverickV2Reward contracts within the specified range.
     */
    function boostedPositionRewards(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory);

    /**
     * @notice Returns the number of reward contracts where the staking token
     * is a booste position that this factory has deployed.
     */
    function boostedPositionRewardsCount() external view returns (uint256 count);

    /**
     * @notice This function retrieves a list of all MaverickV2Reward contracts
     * within a specified range that have a staking token that is not a boosted
     * position from the maverick boosted position contract.
     * @param startIndex The starting index of the list to retrieve.
     * @param endIndex The ending index of the list to retrieve.
     * @return rewardsContract An array of IMaverickV2Reward contracts within the specified range.
     */
    function nonBoostedPositionRewards(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2Reward[] memory);

    /**
     * @notice Returns the number of reward contracts where the staking token
     * is not a booste position that this factory has deployed.
     */
    function nonBoostedPositionRewardsCount() external view returns (uint256 count);
}
