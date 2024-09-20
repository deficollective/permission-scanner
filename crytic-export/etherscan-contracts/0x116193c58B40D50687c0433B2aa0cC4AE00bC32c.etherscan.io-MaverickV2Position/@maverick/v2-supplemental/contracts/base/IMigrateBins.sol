// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

interface IMigrateBins {
    function migrateBinsUpStack(IMaverickV2Pool pool, uint32[] calldata binIds, uint32 maxRecursion) external payable;
}
