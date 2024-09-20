// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IChecks} from "./IChecks.sol";
import {PoolInspection} from "../libraries/PoolInspection.sol";

abstract contract Checks is IChecks {
    /// @inheritdoc IChecks
    function checkSqrtPrice(IMaverickV2Pool pool, uint256 minSqrtPrice, uint256 maxSqrtPrice) public payable {
        uint256 sqrtPrice = PoolInspection.poolSqrtPrice(pool);
        if (sqrtPrice < minSqrtPrice || sqrtPrice > maxSqrtPrice)
            revert PositionExceededPriceBounds(sqrtPrice, minSqrtPrice, maxSqrtPrice);
    }

    /// @inheritdoc IChecks
    function checkDeadline(uint256 deadline) public payable {
        if (block.timestamp > deadline) revert PositionDeadlinePassed(deadline, block.timestamp);
    }
}
