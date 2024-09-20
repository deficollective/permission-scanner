// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2Reward} from "./IMaverickV2Reward.sol";
import {IMaverickV2IncentiveMatcher} from "./IMaverickV2IncentiveMatcher.sol";

interface IMaverickV2IncentiveMatcherCaller {
    error IncentiveMatcherCallerMatchersNotSorted(
        uint256 index,
        IMaverickV2IncentiveMatcher lastMatcher,
        IMaverickV2IncentiveMatcher incentiveMatcher
    );

    function addIncentives(
        IMaverickV2Reward rewardContract,
        uint128 amount,
        uint256 _duration,
        IERC20 token,
        IMaverickV2IncentiveMatcher[] memory incentiveMatchers
    ) external returns (uint256 duration);
}
