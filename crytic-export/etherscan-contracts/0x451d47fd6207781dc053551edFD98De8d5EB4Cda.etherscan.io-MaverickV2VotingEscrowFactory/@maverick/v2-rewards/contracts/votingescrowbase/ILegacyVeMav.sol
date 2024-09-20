// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2VotingEscrow} from "../interfaces/IMaverickV2VotingEscrow.sol";

interface ILegacyVeMav {
    function epoch() external view returns (uint256);
    function lockups(
        address staker,
        uint256 legacyLockupIndex
    ) external view returns (IMaverickV2VotingEscrow.Lockup memory);
    function lockupCount(address staker) external view returns (uint256 count);
    function mav() external view returns (IERC20);
}
