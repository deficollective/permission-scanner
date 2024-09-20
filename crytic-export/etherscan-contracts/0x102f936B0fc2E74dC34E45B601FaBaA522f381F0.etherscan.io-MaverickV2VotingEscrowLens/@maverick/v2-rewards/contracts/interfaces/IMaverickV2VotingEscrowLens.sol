// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2VotingEscrow} from "./IMaverickV2VotingEscrow.sol";
import {IMaverickV2VotingEscrowWSync} from "./IMaverickV2VotingEscrowWSync.sol";

interface IMaverickV2VotingEscrowLens {
    /**
     * @notice This function retrieves paginated claim information for a specific account
     * and claim index range within a provided Maverick V2 Voting Escrow
     * (veToken) contract.
     * @param ve The address of the IMaverickV2VotingEscrow contract for which to retrieve claim information.
     * @param account The address of the account for which to retrieve claim information.
     * @param startIndex The starting index for the desired range of claims.
     * @param endIndex The ending index for the desired range of claims.
     */
    function claimAndBatchInformation(
        IMaverickV2VotingEscrow ve,
        address account,
        uint256 startIndex,
        uint256 endIndex
    )
        external
        view
        returns (
            IMaverickV2VotingEscrow.ClaimInformation[] memory claimInformation,
            IMaverickV2VotingEscrow.BatchInformation[] memory batchInformation
        );

    /**
     * @notice This function retrieves paginated incentive batch information
     * for a provided Maverick V2 Voting Escrow (veToken) contract.
     * @param ve The address of the IMaverickV2VotingEscrow contract for which to retrieve batch information.
     * @param startIndex The starting index for the desired range of claims.
     * @param endIndex The ending index for the desired range of claims.
     */
    function incentiveBatchInformation(
        IMaverickV2VotingEscrow ve,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow.BatchInformation[] memory batchInformation);

    /**
     * @notice This function retrieves paginated information on the lockup
     * synchronization status for legacy ve mav.
     * @param ve The address of the ve contract for which to retrieve sync information.
     * @param staker The address of the user for whom to retrieve sync information.
     * @param startIndex The starting index for the desired range of legacy lockups.
     * @param endIndex The ending index for the desired range of legacy lockups.
     * @return legacyLockups An array of `IMaverickV2VotingEscrow.Lockup`
     * structs containing details about the user's legacy lockups within the
     * index range.
     * @return syncedBalances An array of uint256 values representing the
     * synced balances corresponding to the legacy lockups.
     */
    function syncInformation(
        IMaverickV2VotingEscrowWSync ve,
        address staker,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow.Lockup[] memory legacyLockups, uint256[] memory syncedBalances);

    /**
     * @notice This function retrieves paginated lockup information for a specific
     * account and lockup index range within a provided Maverick V2 Voting
     * Escrow (veToken) contract.
     * @param ve The address of the IMaverickV2VotingEscrow contract for which to retrieve lockup information.
     * @param staker The address of the account for which to retrieve lockup information.
     * @param startIndex The starting index for the desired range of lockups.
     * @param endIndex The ending index for the desired range of lockups.
     * @return returnElements An array of `IMaverickV2VotingEscrow.Lockup`
     * structs containing details about the lockups within the specified index
     * range for the account.
     */
    function getLockups(
        IMaverickV2VotingEscrow ve,
        address staker,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow.Lockup[] memory returnElements);
}
