// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMaverickV2RewardVault {
    error RewardVaultUnauthorizedAccount(address caller, address owner);

    /**
     * @notice This function allows the owner of the reward vault to withdraw a
     * specified amount of staking tokens to a recipient address.  If non-owner
     * calls this function, it will revert.
     * @param recipient The address to which the withdrawn staking tokens will be sent.
     * @param amount The amount of staking tokens to withdraw.
     */
    function withdraw(address recipient, uint256 amount) external;

    /**
     * @notice This function retrieves the address of the owner of the reward
     * vault contract.
     */
    function owner() external view returns (address);

    /**
     * @notice This function retrieves the address of the ERC20 token used for
     * staking within the reward vault.
     */
    function stakingToken() external view returns (IERC20);
}
