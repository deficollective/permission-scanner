// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2VotingEscrow} from "../interfaces/IMaverickV2VotingEscrow.sol";
import {IMaverickV2Reward} from "../interfaces/IMaverickV2Reward.sol";
import {MaverickV2Reward} from "../MaverickV2Reward.sol";

library RewardDeployer {
    function deploy(
        string memory name_,
        string memory symbol_,
        IERC20 _stakingToken,
        IERC20[] memory rewardTokens,
        IMaverickV2VotingEscrow[] memory veTokens
    ) external returns (IMaverickV2Reward reward) {
        reward = new MaverickV2Reward(name_, symbol_, _stakingToken, rewardTokens, veTokens);
    }
}
