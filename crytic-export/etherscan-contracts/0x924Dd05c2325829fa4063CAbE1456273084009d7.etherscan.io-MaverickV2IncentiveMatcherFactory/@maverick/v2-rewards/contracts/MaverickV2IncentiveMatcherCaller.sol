// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IMaverickV2Reward} from "./interfaces/IMaverickV2Reward.sol";
import {IMaverickV2IncentiveMatcher} from "./interfaces/IMaverickV2IncentiveMatcher.sol";
import {IMaverickV2IncentiveMatcherCaller} from "./interfaces/IMaverickV2IncentiveMatcherCaller.sol";

/**
 * @notice Allows users to add rewards to multiple incentive matchers and get
 * credit for that incentive in multiple matcher contracts.
 */
contract MaverickV2IncentiveMatcherCaller is IMaverickV2IncentiveMatcherCaller, ReentrancyGuard {
    using SafeERC20 for IERC20;

    function addIncentives(
        IMaverickV2Reward rewardContract,
        uint128 amount,
        uint256 _duration,
        IERC20 token,
        IMaverickV2IncentiveMatcher[] memory incentiveMatchers
    ) public nonReentrant returns (uint256 duration) {
        IMaverickV2IncentiveMatcher lastMatcher;
        for (uint256 k; k < incentiveMatchers.length; k++) {
            if (lastMatcher >= incentiveMatchers[k])
                revert IncentiveMatcherCallerMatchersNotSorted(k, lastMatcher, incentiveMatchers[k]);

            incentiveMatchers[k].permissionedAddIncentives(rewardContract, amount, token);

            lastMatcher = incentiveMatchers[k];
        }

        token.safeTransferFrom(msg.sender, address(rewardContract), amount);
        // reverts if token is not valid for reward contract
        duration = rewardContract.notifyRewardAmount(token, _duration);
    }
}
