// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";

interface IMaverickV2VotingEscrowFactory {
    error VotingEscrowTokenAlreadyExists(IERC20 baseToken, IMaverickV2VotingEscrow veToken);

    event CreateVotingEscrow(IERC20 baseToken, IMaverickV2VotingEscrow veToken);

    /**
     * @notice This function retrieves the address of the legacy Maverick V1
     * Voting Escrow (veMAV) token.  The address will be zero for blockchains
     * where this contract is deployed that do not have a legacy MAV contract
     * deployed.
     * @return legacyVeMav The address of the IERC20 legacy veMav token.
     */
    function legacyVeMav() external view returns (IERC20);

    /**
     * @notice This function checks whether a provided IMaverickV2VotingEscrow
     * contract address was created by this factory.
     * @param veToken The address of the IMaverickV2VotingEscrow contract to be checked.
     * @return isFactoryToken True if the veToken was created by this factory, False otherwise (bool).
     */
    function isFactoryToken(IMaverickV2VotingEscrow veToken) external view returns (bool);

    /**
     * @notice This function creates a new Maverick V2 Voting Escrow (veToken)
     * contract for a specified ERC20 base token.
     * @dev Once the ve contract is created, it will call `name()` and
     * `symbol()` on the `baseToken`.  If those functions do not exist, the ve
     * creation will revert.
     * @param baseToken The address of the ERC-20 token to be used as the base token for the new veToken.
     * @return veToken The address of the newly created IMaverickV2VotingEscrow contract.
     */
    function createVotingEscrow(IERC20 baseToken) external returns (IMaverickV2VotingEscrow veToken);

    /**
     * @notice This function retrieves a paginated list of existing Maverick V2
     * Voting Escrow (veToken) contracts within a specified index range.
     * @param startIndex The starting index for the desired range of veTokens.
     * @param endIndex The ending index for the desired range of veTokens.
     * @return votingEscrows An array of IMaverickV2VotingEscrow addresses
     * representing the veTokens within the specified range.
     */
    function votingEscrows(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow[] memory votingEscrows);

    /**
     * @notice This function retrieves the total number of deployed Maverick V2
     * Voting Escrow (veToken) contracts.
     * @return count The total number of veTokens.
     */
    function votingEscrowsCount() external view returns (uint256 count);

    /**
     * @notice This function retrieves the address of the existing Maverick V2
     * Voting Escrow (veToken) contract associated with a specific ERC20 base
     * token.
     * @param baseToken The address of the ERC-20 base token for which to retrieve the veToken address.
     * @return veToken The address of the IMaverickV2VotingEscrow contract
     * associated with the base token, or the zero address if none exists.
     */
    function veForBaseToken(IERC20 baseToken) external view returns (IMaverickV2VotingEscrow veToken);

    /**
     * @notice This function retrieves the default base token used for creating
     * new voting escrow contracts.  This state variable is only used
     * temporarily when a new veToken is deployed.
     * @return baseToken The address of the default ERC-20 base token.
     */
    function baseTokenParameter() external returns (IERC20);
}
