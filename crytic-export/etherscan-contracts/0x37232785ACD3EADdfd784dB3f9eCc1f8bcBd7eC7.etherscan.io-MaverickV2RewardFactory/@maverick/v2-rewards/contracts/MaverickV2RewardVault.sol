// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2RewardVault} from "./interfaces/IMaverickV2RewardVault.sol";

/**
 * @notice Vault contract with owner-only withdraw function.  Used by the
 * Reward contract to segregate staking funds from incentive rewards funds.
 */
contract MaverickV2RewardVault is IMaverickV2RewardVault {
    using SafeERC20 for IERC20;

    /// @inheritdoc IMaverickV2RewardVault
    address public immutable owner;

    /// @inheritdoc IMaverickV2RewardVault
    IERC20 public immutable stakingToken;

    constructor(IERC20 _stakingToken) {
        owner = msg.sender;
        stakingToken = _stakingToken;
    }

    /// @inheritdoc IMaverickV2RewardVault
    function withdraw(address recipient, uint256 amount) public {
        if (owner != msg.sender) {
            revert RewardVaultUnauthorizedAccount(msg.sender, owner);
        }
        stakingToken.safeTransfer(recipient, amount);
    }
}
