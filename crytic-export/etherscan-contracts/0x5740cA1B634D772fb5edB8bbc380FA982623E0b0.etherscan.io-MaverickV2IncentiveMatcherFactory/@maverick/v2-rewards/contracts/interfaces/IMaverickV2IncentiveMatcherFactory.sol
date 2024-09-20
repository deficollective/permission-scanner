// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";
import {IMaverickV2RewardFactory} from "./IMaverickV2RewardFactory.sol";
import {IMaverickV2IncentiveMatcher} from "./IMaverickV2IncentiveMatcher.sol";
import {IMaverickV2VotingEscrowFactory} from "./IMaverickV2VotingEscrowFactory.sol";

interface IMaverickV2IncentiveMatcherFactory {
    error VotingEscrowTokenDoesNotExists(IERC20 baseToken);

    event CreateIncentiveMatcher(
        IERC20 baseToken,
        IMaverickV2VotingEscrow veToken,
        IMaverickV2IncentiveMatcher incentiveMatcher
    );

    struct IncentiveMatcherParameters {
        IERC20 baseToken;
        IMaverickV2VotingEscrow veToken;
        IMaverickV2RewardFactory factory;
    }

    function incentiveMatcherParameters()
        external
        view
        returns (IERC20 baseToken, IMaverickV2VotingEscrow veToken, IMaverickV2RewardFactory factory);

    /**
     * @notice This function retrieves the address of the MaverickV2VotingEscrowFactory contract.
     * @return The address of the MaverickV2VotingEscrowFactory contract.
     */
    function veFactory() external view returns (IMaverickV2VotingEscrowFactory);

    /**
     * @notice This function retrieves the address of the MaverickV2RewardFactory contract.
     * @return The address of the MaverickV2RewardFactory contract.
     */
    function rewardFactory() external view returns (IMaverickV2RewardFactory);

    /**
     * @notice This function checks if the current contract is a factory contract for IncentiveMatchers.
     * @param incentiveMatcher The address of the corresponding IncentiveMatcher contract.
     * @return isFactoryContract True if the contract is a factory contract, False otherwise.
     */
    function isFactoryIncentiveMatcher(
        IMaverickV2IncentiveMatcher incentiveMatcher
    ) external view returns (bool isFactoryContract);

    /**
     * @notice This function retrieves the address of the IncentiveMatcher
     * contract associated with the current veToken.
     * @param veToken The voting escrow token to look up.
     * @return incentiveMatcher The address of the corresponding IncentiveMatcher contract.
     */
    function incentiveMatcherForVe(
        IMaverickV2VotingEscrow veToken
    ) external view returns (IMaverickV2IncentiveMatcher incentiveMatcher);

    /**
     * @notice This function creates a new IncentiveMatcher contract for a
     * given base token.  The basetoken is required to have a deployed ve token
     * before incentive matcher can be created. If no ve token exists, this
     * function will revert.  A ve token can be created with the ve token
     * factory: `veFactory()`.
     * @param baseToken The base token for the new IncentiveMatcher.
     * @return veToken The voting escrow token for the IncentiveMatcher.
     * @return incentiveMatcher The address of the newly created IncentiveMatcher contract.
     */
    function createIncentiveMatcher(
        IERC20 baseToken
    ) external returns (IMaverickV2VotingEscrow veToken, IMaverickV2IncentiveMatcher incentiveMatcher);

    /**
     * @notice This function retrieves a list of existing IncentiveMatcher contracts.
     * @param startIndex The starting index of the list to retrieve.
     * @param endIndex The ending index of the list to retrieve.
     * @return returnElements An array of IncentiveMatcher contracts within the specified range.
     */
    function incentiveMatchers(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2IncentiveMatcher[] memory returnElements);

    /**
     * @notice This function returns the total number of existing IncentiveMatcher contracts.
     */
    function incentiveMatchersCount() external view returns (uint256 count);
}
