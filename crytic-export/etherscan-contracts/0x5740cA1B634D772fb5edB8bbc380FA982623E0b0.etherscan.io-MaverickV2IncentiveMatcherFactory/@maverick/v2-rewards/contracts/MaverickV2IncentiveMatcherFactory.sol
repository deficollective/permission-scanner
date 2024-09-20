// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {IMaverickV2VotingEscrowFactory} from "./interfaces/IMaverickV2VotingEscrowFactory.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2RewardFactory} from "./interfaces/IMaverickV2RewardFactory.sol";
import {IMaverickV2IncentiveMatcher} from "./interfaces/IMaverickV2IncentiveMatcher.sol";
import {IMaverickV2IncentiveMatcherFactory} from "./interfaces/IMaverickV2IncentiveMatcherFactory.sol";

import {IncentiveMatcherDeployer} from "./libraries/IncentiveMatcherDeployer.sol";

/**
 * @notice IncentiveMatcherFactory creates IncentiveMatcher contracts that
 * can be used  to facilitate voting on incentive directing and external protocol
 * incentive matching for a given veToken.
 *
 * @dev IncentiveMatcher contracts are deployed with create2 to deterministic
 * addresses can computed prior to deployment.
 */
contract MaverickV2IncentiveMatcherFactory is IMaverickV2IncentiveMatcherFactory {
    IncentiveMatcherParameters public incentiveMatcherParameters;

    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    mapping(IMaverickV2VotingEscrow => IMaverickV2IncentiveMatcher) public override incentiveMatcherForVe;
    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    mapping(IMaverickV2IncentiveMatcher => bool) public isFactoryIncentiveMatcher;
    IMaverickV2IncentiveMatcher[] private _allIncentiveMatcher;

    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    IMaverickV2VotingEscrowFactory public immutable veFactory;
    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    IMaverickV2RewardFactory public immutable rewardFactory;

    constructor(IMaverickV2VotingEscrowFactory _veFactory, IMaverickV2RewardFactory _rewardFactory) {
        veFactory = _veFactory;
        rewardFactory = _rewardFactory;
    }

    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    function createIncentiveMatcher(
        IERC20 baseToken
    ) public returns (IMaverickV2VotingEscrow veToken, IMaverickV2IncentiveMatcher incentiveMatcher) {
        veToken = veFactory.veForBaseToken(baseToken);
        if (veToken == IMaverickV2VotingEscrow(address(0)) || veToken.baseToken() != baseToken)
            revert VotingEscrowTokenDoesNotExists(baseToken);

        // deploy IncentiveMatcher
        incentiveMatcherParameters = IncentiveMatcherParameters({
            baseToken: baseToken,
            veToken: veToken,
            factory: rewardFactory
        });
        incentiveMatcher = IncentiveMatcherDeployer.deploy(veToken, rewardFactory);
        delete incentiveMatcherParameters;
        isFactoryIncentiveMatcher[incentiveMatcher] = true;
        incentiveMatcherForVe[veToken] = incentiveMatcher;
        _allIncentiveMatcher.push(incentiveMatcher);

        emit CreateIncentiveMatcher(baseToken, veToken, incentiveMatcher);
    }

    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    function incentiveMatchers(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2IncentiveMatcher[] memory returnElements) {
        endIndex = Math.min(_allIncentiveMatcher.length, endIndex);
        returnElements = new IMaverickV2IncentiveMatcher[](endIndex - startIndex);

        // endIndex >= startIndex is ensured in the subtraction above.
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                returnElements[i - startIndex] = _allIncentiveMatcher[i];
            }
        }
    }

    /// @inheritdoc IMaverickV2IncentiveMatcherFactory
    function incentiveMatchersCount() external view returns (uint256 count) {
        return _allIncentiveMatcher.length;
    }
}
