// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Import is relative to ensure the expected version of OZ is used when installed as a library in other repos.
import { ERC4626, ERC20, IERC20, Math } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title PoolTogether V5 ERC4626 Staking Vault
/// @notice A staking vault that accepts deposits of an underlying asset and mints shares at a 1:1 ratio.
/// @author G9 Software Inc.
contract StakingVault is ERC4626 {

    /// @notice Constructs a new staking vault
    /// @param name The name of the vault
    /// @param symbol The symbol for the vault shares
    /// @param asset The underlying asset that will be accepted for deposits
    constructor(string memory name, string memory symbol, IERC20 asset) ERC20(name, symbol) ERC4626(asset) { }

    /// @dev Overrides the default conversion to ensure a 1:1 asset to share ratio
    function _convertToShares(uint256 assets, Math.Rounding /* rounding */) internal pure override returns (uint256) {
        return assets;
    }

    /// @dev Overrides the default conversion to ensure a 1:1 asset to share ratio
    function _convertToAssets(uint256 shares, Math.Rounding /* rounding */) internal pure override returns (uint256) {
        return shares;
    }

}
