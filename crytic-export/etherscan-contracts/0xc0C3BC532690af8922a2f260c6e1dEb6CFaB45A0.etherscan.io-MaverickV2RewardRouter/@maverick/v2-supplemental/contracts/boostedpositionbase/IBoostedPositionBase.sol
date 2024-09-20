// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMulticall} from "@maverick/v2-common/contracts/base/IMulticall.sol";

import {IChecks} from "../base/IChecks.sol";

interface IBoostedPositionBase is IERC20Metadata, IChecks, IMulticall {
    /**
     * @notice BP Pool.
     */
    function pool() external view returns (IMaverickV2Pool pool_);

    /**
     * @notice BP Bin kind (static, right, left, both).
     */
    function kind() external view returns (uint8 kind_);

    /**
     * @notice Number of bins in the BP.
     */
    function binCount() external view returns (uint8 binCount_);

    /**
     * @notice Liquidity balance in BP bins since last mint/burn operation.
     */
    function getBinBalances() external view returns (uint128[] memory binBalances_);

    /**
     * @notice Liquidity balance in given BP bin since last mint/burn
     * operation.
     */
    function binBalances(uint256 index) external view returns (uint128 binBalance);
}
