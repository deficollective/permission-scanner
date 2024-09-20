// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {ONE} from "@maverick/v2-common/contracts/libraries/Constants.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {IMaverickV2BoostedPositionFactory} from "./interfaces/IMaverickV2BoostedPositionFactory.sol";
import {BoostedPositionDeployerStatic} from "./libraries/BoostedPositionDeployerStatic.sol";
import {BoostedPositionDeployerDynamic} from "./libraries/BoostedPositionDeployerDynamic.sol";

/**
 * @notice Factory contract that deploys Maverick V2 Boosted Positions.
 */
contract MaverickV2BoostedPositionFactory is IMaverickV2BoostedPositionFactory {
    string private constant NAME_PREFIX = "Maverick BP-";
    string private constant SYMBOL_PREFIX = "MBP-";
    IMaverickV2BoostedPosition[] private _allBoostedPositions;
    mapping(IMaverickV2Pool => IMaverickV2BoostedPosition[]) private _boostedPositionsByPool;

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    IMaverickV2Factory public immutable poolFactory;

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    mapping(IMaverickV2BoostedPosition => bool) public isFactoryBoostedPosition;

    /**
     * @dev Factory will only deploy BPs from the specified pool factory.
     */
    constructor(IMaverickV2Factory _poolFactory) {
        poolFactory = _poolFactory;
    }

    function _createParameterValidation(
        IMaverickV2Pool pool,
        uint32[] memory binIds,
        uint128[] memory ratios,
        uint8 kind
    ) internal view {
        if (!poolFactory.isFactoryPool(pool)) revert BoostedPositionFactoryNotFactoryPool();
        if (pool.permissionedLiquidity()) revert BoostedPositionPermissionedLiquidityPool();
        if (ratios[0] != ONE) revert BoostedPositionFactoryInvalidRatioZero(ratios[0]);
        if (ratios.length != binIds.length) revert BoostedPositionFactoryInvalidLengths(ratios.length, binIds.length);
        if (kind != 0 && ratios.length != 1) revert BoostedPositionFactoryInvalidLengthForKind(kind, ratios.length);
        if (ratios.length > 24) revert BoostedPositionFactoryInvalidLengthForKind(kind, ratios.length);

        uint32 lastBinId;
        for (uint256 k; k < binIds.length; k++) {
            if (binIds[k] <= lastBinId) revert BoostedPositionFactoryBinIdsNotSorted(k, lastBinId, binIds[k]);
            uint8 kind_ = pool.getBin(binIds[k]).kind;
            if (kind != kind_) revert BoostedPositionFactoryInvalidBinKind(kind, kind_, binIds[k]);
            lastBinId = binIds[k];
        }
    }

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    function createBoostedPosition(
        IMaverickV2Pool pool,
        uint32[] memory binIds,
        uint128[] memory ratios,
        uint8 kind
    ) external returns (IMaverickV2BoostedPosition boostedPosition) {
        _createParameterValidation(pool, binIds, ratios, kind);

        string memory suffix = string(
            abi.encodePacked(
                IERC20Metadata(address(pool.tokenA())).symbol(),
                "-",
                IERC20Metadata(address(pool.tokenB())).symbol(),
                "-",
                Strings.toString(_allBoostedPositions.length + 1)
            )
        );
        string memory name = string.concat(NAME_PREFIX, suffix);
        string memory symbol = string.concat(SYMBOL_PREFIX, suffix);

        if (kind == 0) {
            boostedPosition = BoostedPositionDeployerStatic.deploy(
                name,
                symbol,
                pool,
                uint8(binIds.length),
                _packBinIds(binIds),
                _packRatios(ratios)
            );
        } else {
            uint8 decimalsA = IERC20Metadata(address(pool.tokenA())).decimals();
            uint8 decimalsB = IERC20Metadata(address(pool.tokenB())).decimals();
            boostedPosition = BoostedPositionDeployerDynamic.deploy(
                name,
                symbol,
                pool,
                kind,
                binIds[0],
                Math.scale(decimalsA),
                Math.scale(decimalsB)
            );
        }
        _allBoostedPositions.push(boostedPosition);
        _boostedPositionsByPool[pool].push(boostedPosition);
        isFactoryBoostedPosition[boostedPosition] = true;

        emit CreateBoostedPosition(pool, binIds, ratios, kind, boostedPosition);
    }

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    function lookup(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2BoostedPosition[] memory returnBoostedPositions) {
        endIndex = Math.min(_allBoostedPositions.length, endIndex);
        returnBoostedPositions = new IMaverickV2BoostedPosition[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            returnBoostedPositions[i - startIndex] = _allBoostedPositions[i];
        }
    }

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    function boostedPositionsCount() external view returns (uint256 count) {
        count = _allBoostedPositions.length;
    }

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    function lookup(
        IMaverickV2Pool pool,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2BoostedPosition[] memory returnBoostedPositions) {
        endIndex = Math.min(_boostedPositionsByPool[pool].length, endIndex);
        returnBoostedPositions = new IMaverickV2BoostedPosition[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            returnBoostedPositions[i - startIndex] = _boostedPositionsByPool[pool][i];
        }
    }

    /// @inheritdoc IMaverickV2BoostedPositionFactory
    function boostedPositionsByPoolCount(IMaverickV2Pool pool) external view returns (uint256 count) {
        count = _boostedPositionsByPool[pool].length;
    }

    function _packBinIds(uint32[] memory binIds) private pure returns (bytes32[3] memory binIdsBytes) {
        uint256 length = binIds.length;
        for (uint256 wordIndex; wordIndex < 3; wordIndex++) {
            uint256 shift = wordIndex * 8;
            if (shift < length) {
                binIdsBytes[wordIndex] = bytes32(
                    abi.encodePacked(
                        length > 7 + shift ? binIds[7 + shift] : 0,
                        length > 6 + shift ? binIds[6 + shift] : 0,
                        length > 5 + shift ? binIds[5 + shift] : 0,
                        length > 4 + shift ? binIds[4 + shift] : 0,
                        length > 3 + shift ? binIds[3 + shift] : 0,
                        length > 2 + shift ? binIds[2 + shift] : 0,
                        length > 1 + shift ? binIds[1 + shift] : 0,
                        length > shift ? binIds[shift] : 0
                    )
                );
            }
        }
    }

    function _packRatios(uint128[] memory ratios) internal pure returns (bytes32[12] memory ratiosBytes) {
        uint256 length = ratios.length;
        for (uint256 wordIndex; wordIndex < 12; wordIndex++) {
            uint256 shift = wordIndex * 2;
            if (shift < length) {
                ratiosBytes[wordIndex] = bytes32(
                    abi.encodePacked(length > shift + 1 ? ratios[shift + 1] : 0, length > shift ? ratios[shift] : 0)
                );
            }
        }
    }
}
