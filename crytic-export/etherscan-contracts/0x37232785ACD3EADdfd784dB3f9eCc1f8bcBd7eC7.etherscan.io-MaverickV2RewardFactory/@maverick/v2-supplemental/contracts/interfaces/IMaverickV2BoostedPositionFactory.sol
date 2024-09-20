// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IMaverickV2BoostedPosition} from "./IMaverickV2BoostedPosition.sol";

interface IMaverickV2BoostedPositionFactory {
    error BoostedPositionFactoryNotFactoryPool();
    error BoostedPositionPermissionedLiquidityPool();
    error BoostedPositionFactoryKindNotSupportedByPool(uint8 poolKinds, uint8 kind);
    error BoostedPositionFactoryInvalidRatioZero(uint128 ratioZero);
    error BoostedPositionFactoryInvalidLengths(uint256 ratioLength, uint256 binIdsLength);
    error BoostedPositionFactoryInvalidLengthForKind(uint8 kind, uint256 ratiosLength);
    error BoostedPositionFactoryBinIdsNotSorted(uint256 index, uint32 lastBinId, uint32 thisBinId);
    error BoostedPositionFactoryInvalidBinKind(uint8 inputKind, uint8 binKind, uint32 binId);

    event CreateBoostedPosition(
        IMaverickV2Pool pool,
        uint32[] binIds,
        uint128[] ratios,
        uint8 kind,
        IMaverickV2BoostedPosition boostedPosition
    );

    /**
     * @notice Creates BP from the specified input parameters.  Requirements:
     *
     * - Pool must be from pool factory
     * - BP kind must be supported by the pool
     * - BinIds have to be sorted in ascending order
     * - ratios[0] must be 1e18; ratios are specified in D18 scale
     * - ratio and binId arrays have to be the same length
     * - movement-mode BPs can only have one binId
     * - static-mode BPs can have at most 24 binIds
     */
    function createBoostedPosition(
        IMaverickV2Pool pool,
        uint32[] memory binIds,
        uint128[] memory ratios,
        uint8 kind
    ) external returns (IMaverickV2BoostedPosition boostedPosition);

    /**
     * @notice Look up BPs by range of indexes.
     */
    function lookup(uint256 startIndex, uint256 endIndex) external view returns (IMaverickV2BoostedPosition[] memory);

    /**
     * @notice Returns count of all BPs deployed by the factory.
     */
    function boostedPositionsCount() external view returns (uint256 count);

    /**
     * @notice Look up BPs by range of indexes for a given pool.
     */
    function lookup(
        IMaverickV2Pool pool,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2BoostedPosition[] memory);

    /**
     * @notice Returns count of all BPs deployed by the factory for a given
     * pool.
     */
    function boostedPositionsByPoolCount(IMaverickV2Pool pool) external view returns (uint256 count);

    /**
     * @notice Returns whether or not input BP was created by this factory.
     */
    function isFactoryBoostedPosition(IMaverickV2BoostedPosition) external returns (bool);

    /**
     * @notice Pool factory that all BPs pool must be deployed from.
     */
    function poolFactory() external returns (IMaverickV2Factory);
}
