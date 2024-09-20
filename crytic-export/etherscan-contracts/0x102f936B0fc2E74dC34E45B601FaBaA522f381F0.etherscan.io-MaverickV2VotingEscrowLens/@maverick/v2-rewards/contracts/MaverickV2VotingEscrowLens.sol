// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {ILegacyVeMav} from "./votingescrowbase/ILegacyVeMav.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2VotingEscrowLens} from "./interfaces/IMaverickV2VotingEscrowLens.sol";
import {IMaverickV2VotingEscrowWSync} from "./interfaces/IMaverickV2VotingEscrowWSync.sol";

/**
 * @notice Provides view functions for voting escrow information.
 */
contract MaverickV2VotingEscrowLens is IMaverickV2VotingEscrowLens {
    /// @inheritdoc IMaverickV2VotingEscrowLens
    function claimAndBatchInformation(
        IMaverickV2VotingEscrow ve,
        address account,
        uint256 startIndex,
        uint256 endIndex
    )
        public
        view
        returns (
            IMaverickV2VotingEscrow.ClaimInformation[] memory claimInformation,
            IMaverickV2VotingEscrow.BatchInformation[] memory batchInformation
        )
    {
        endIndex = Math.min(ve.incentiveBatchCount(), endIndex);
        claimInformation = new IMaverickV2VotingEscrow.ClaimInformation[](endIndex - startIndex);
        batchInformation = new IMaverickV2VotingEscrow.BatchInformation[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                (claimInformation[i - startIndex], batchInformation[i - startIndex]) = ve.claimAndBatchInformation(
                    account,
                    i
                );
            }
        }
    }

    function incentiveBatchInformation(
        IMaverickV2VotingEscrow ve,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow.BatchInformation[] memory batchInformation) {
        endIndex = Math.min(ve.incentiveBatchCount(), endIndex);
        batchInformation = new IMaverickV2VotingEscrow.BatchInformation[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                batchInformation[i - startIndex] = ve.incentiveBatchInformation(i);
            }
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowLens
    function syncInformation(
        IMaverickV2VotingEscrowWSync ve,
        address staker,
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (IMaverickV2VotingEscrow.Lockup[] memory legacyLockups, uint256[] memory syncedBalances) {
        ILegacyVeMav legacyVeMav = ILegacyVeMav(address(ve.legacyVeMav()));
        uint256 legacyLength = legacyVeMav.lockupCount(staker);
        endIndex = Math.min(legacyLength, endIndex);
        legacyLockups = new IMaverickV2VotingEscrow.Lockup[](endIndex - startIndex);
        syncedBalances = new uint256[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                legacyLockups[i - startIndex] = legacyVeMav.lockups(staker, i);
                syncedBalances[i - startIndex] = ve.syncBalances(staker, i);
            }
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowLens
    function getLockups(
        IMaverickV2VotingEscrow ve,
        address staker,
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (IMaverickV2VotingEscrow.Lockup[] memory returnElements) {
        endIndex = Math.min(ve.lockupCount(staker), endIndex);
        returnElements = new IMaverickV2VotingEscrow.Lockup[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                returnElements[i - startIndex] = ve.getLockup(staker, i);
            }
        }
    }
}
