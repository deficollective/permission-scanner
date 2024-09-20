// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2IncentiveMatcher} from "../interfaces/IMaverickV2IncentiveMatcher.sol";
import {IMaverickV2RewardFactory} from "../interfaces/IMaverickV2RewardFactory.sol";
import {IMaverickV2VotingEscrow} from "../interfaces/IMaverickV2VotingEscrow.sol";
import {MaverickV2IncentiveMatcher} from "../MaverickV2IncentiveMatcher.sol";

library IncentiveMatcherDeployer {
    function deploy(
        IMaverickV2VotingEscrow veToken,
        IMaverickV2RewardFactory factory
    ) external returns (IMaverickV2IncentiveMatcher incentiveMatcher) {
        incentiveMatcher = new MaverickV2IncentiveMatcher{salt: keccak256(abi.encode(veToken, factory))}();
    }
}
