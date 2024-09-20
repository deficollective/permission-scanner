// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

interface IChecks {
    error PositionExceededPriceBounds(uint256 sqrtPrice, uint256 minSqrtPrice, uint256 maxSqrtPrice);
    error PositionDeadlinePassed(uint256 deadline, uint256 blockTimestamp);

    /**
     * @notice Function to check if the price of a pool is within specified bounds.
     * @param pool The MaverickV2Pool contract to check.
     * @param minSqrtPrice The minimum acceptable square root price.
     * @param maxSqrtPrice The maximum acceptable square root price.
     */
    function checkSqrtPrice(IMaverickV2Pool pool, uint256 minSqrtPrice, uint256 maxSqrtPrice) external payable;

    /**
     * @notice Function to check if a given deadline has passed.
     * @param deadline The timestamp representing the deadline.
     */
    function checkDeadline(uint256 deadline) external payable;
}
