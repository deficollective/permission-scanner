// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMigrateBins} from "./IMigrateBins.sol";

abstract contract MigrateBins is IMigrateBins {
    /**
     * @dev Migrates bins up the stack in the pool.
     * @param pool The MaverickV2Pool contract.
     * @param binIds An array of bin IDs to migrate.
     * @param maxRecursion The maximum recursion depth.
     */
    function migrateBinsUpStack(IMaverickV2Pool pool, uint32[] memory binIds, uint32 maxRecursion) public payable {
        for (uint256 i = 0; i < binIds.length; i++) {
            pool.migrateBinUpStack(binIds[i], maxRecursion);
        }
    }
}
