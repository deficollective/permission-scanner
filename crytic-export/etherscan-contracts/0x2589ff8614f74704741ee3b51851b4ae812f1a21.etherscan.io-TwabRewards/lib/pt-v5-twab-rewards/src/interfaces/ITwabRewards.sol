// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/**
 * @notice Struct to keep track of each promotion's settings.
 * @param creator Address of the promotion creator
 * @param startTimestamp Timestamp at which the promotion starts
 * @param numberOfEpochs Number of epochs the promotion will last for
 * @param vault Address of the vault that the promotion applies to
 * @param epochDuration Duration of one epoch in seconds
 * @param createdAt Timestamp at which the promotion was created
 * @param token Address of the token to be distributed as reward
 * @param tokensPerEpoch Number of tokens to be distributed per epoch
 * @param rewardsUnclaimed Amount of rewards that have not been claimed yet
 */
struct Promotion {
    address creator;
    uint64 startTimestamp;
    uint8 numberOfEpochs;
    address vault;
    uint48 epochDuration;
    uint48 createdAt;
    IERC20 token;
    uint256 tokensPerEpoch;
    uint256 rewardsUnclaimed;
}

/**
 * @title  PoolTogether V5 ITwabRewards
 * @author PoolTogether Inc. & G9 Software Inc.
 * @notice TwabRewards contract interface.
 */
interface ITwabRewards {
    /**
     * @notice Creates a new promotion.
     * @param vault Address of the vault that the promotion applies to
     * @param token Address of the token to be distributed
     * @param startTimestamp Timestamp at which the promotion starts
     * @param tokensPerEpoch Number of tokens to be distributed per epoch
     * @param epochDuration Duration of one epoch in seconds
     * @param numberOfEpochs Number of epochs the promotion will last for
     * @return Id of the newly created promotion
     */
    function createPromotion(
        address vault,
        IERC20 token,
        uint64 startTimestamp,
        uint256 tokensPerEpoch,
        uint48 epochDuration,
        uint8 numberOfEpochs
    ) external returns (uint256);

    /**
     * @notice End currently active promotion and send promotion tokens back to the creator.
     * @dev Will only send back tokens from the epochs that have not completed.
     * @param promotionId Promotion id to end
     * @param to Address that will receive the remaining tokens if there are any left
     * @return True if operation was successful
     */
    function endPromotion(uint256 promotionId, address to) external returns (bool);

    /**
     * @notice Delete an inactive promotion and send promotion tokens back to the creator.
     * @dev Will send back all the tokens that have not been claimed yet by users.
     * @dev This function will revert if the promotion is still active.
     * @dev This function will revert if the grace period is not over yet.
     * @param promotionId Promotion id to destroy
     * @param to Address that will receive the remaining tokens if there are any left
     * @return True if operation was successful
     */
    function destroyPromotion(uint256 promotionId, address to) external returns (bool);

    /**
     * @notice Extend promotion by adding more epochs.
     * @param promotionId Id of the promotion to extend
     * @param numberOfEpochs Number of epochs to add
     * @return True if the operation was successful
     */
    function extendPromotion(uint256 promotionId, uint8 numberOfEpochs) external returns (bool);

    /**
     * @notice Claim rewards for a given promotion and epoch.
     * @dev Rewards can be claimed on behalf of a user.
     * @dev Rewards can only be claimed for a past epoch.
     * @param user Address of the user to claim rewards for
     * @param promotionId Id of the promotion to claim rewards for
     * @param epochIds Epoch ids to claim rewards for
     * @return Total amount of rewards claimed
     */
    function claimRewards(address user, uint256 promotionId, uint8[] calldata epochIds) external returns (uint256);

    /**
     * @notice Get settings for a specific promotion.
     * @param promotionId Id of the promotion to get settings for
     * @return Promotion settings
     */
    function getPromotion(uint256 promotionId) external view returns (Promotion memory);

    /**
     * @notice Get the current epoch id of a promotion.
     * @param promotionId Id of the promotion to get current epoch for
     * @return Current epoch id of the promotion
     */
    function getCurrentEpochId(uint256 promotionId) external view returns (uint256);

    /**
     * @notice Get the total amount of tokens left to be rewarded.
     * @param promotionId Id of the promotion to get the total amount of tokens left to be rewarded for
     * @return Amount of tokens left to be rewarded
     */
    function getRemainingRewards(uint256 promotionId) external view returns (uint256);

    /**
     * @notice Get amount of tokens to be rewarded for a given epoch.
     * @dev Rewards amount can only be retrieved for epochs that are over.
     * @dev Will revert if `epochId` is over the total number of epochs or if epoch is not over.
     * @dev Will return 0 if the user average balance for the promoted vault is 0.
     * @dev Will be 0 if user has already claimed rewards for the epoch.
     * @param user Address of the user to get amount of rewards for
     * @param promotionId Id of the promotion from which the epoch is
     * @param epochIds Epoch ids to get reward amount for
     * @return Amount of tokens per epoch to be rewarded
     */
    function getRewardsAmount(
        address user,
        uint256 promotionId,
        uint8[] calldata epochIds
    ) external view returns (uint256[] memory);
}
