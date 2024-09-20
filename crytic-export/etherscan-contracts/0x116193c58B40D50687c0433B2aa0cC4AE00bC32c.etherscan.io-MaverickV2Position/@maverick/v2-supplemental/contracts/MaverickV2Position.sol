// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {Multicall} from "@maverick/v2-common/contracts/base/Multicall.sol";
import {ONE} from "@maverick/v2-common/contracts/libraries/Constants.sol";
import {ArrayOperations} from "@maverick/v2-common/contracts/libraries/ArrayOperations.sol";

import {IMaverickV2Position} from "./interfaces/IMaverickV2Position.sol";
import {IPositionImage} from "./interfaces/IPositionImage.sol";

import {PoolInspection} from "./libraries/PoolInspection.sol";
import {Nft, INft} from "./positionbase/Nft.sol";
import {MigrateBins} from "./base/MigrateBins.sol";
import {Checks} from "./base/Checks.sol";

/**
 * @notice ERC-721 contract that stores user NFTs that contain Maverick V2 pool
 * liquidity.
 *
 * @dev The Maverick V2 pool has a concept of storing liquidity according to an
 * address and a "subaccount".  When liquidity is minted to an NFT, it is
 * stored in the pool to the address of this Position contract to the
 * subaccount that corresponds to the NFT tokenId.  The mechanism of liquidity
 * management is that the tokenId owner is the only user who can remove pool
 * liquidity in the subaccount corresponding to their tokenId.
 *
 * @dev Additionally, this position NFT has data about the pools and binIds
 * that a given tokenId has liquidity in. But these binId/pool values are
 * essentially self reported and can be updated by the token owner by calling
 * setTokenIdData.
 */
contract MaverickV2Position is Nft, Checks, MigrateBins, Multicall, IMaverickV2Position {
    using Cast for uint256;
    using ArrayOperations for uint32[];

    IPositionImage public immutable positionImage;
    IMaverickV2Factory public immutable factory;

    mapping(uint256 => PositionPoolBinIds[]) private dataByTokenId;

    constructor(IPositionImage _positionImage, IMaverickV2Factory _factory) Nft("Maverick v2 Position", "MPv2") {
        factory = _factory;
        positionImage = _positionImage;
    }

    /// @inheritdoc IMaverickV2Position
    function mint(address recipient, IMaverickV2Pool pool, uint32[] memory binIds) public returns (uint256 tokenId) {
        tokenId = _mint(recipient);
        PositionPoolBinIds memory data = PositionPoolBinIds(pool, binIds);
        _checkData(data);
        dataByTokenId[tokenId].push(data);
        emit PositionSetData(tokenId, 0, data);
    }

    /// @inheritdoc IMaverickV2Position
    function removeLiquidity(
        uint256 tokenId,
        address recipient,
        IMaverickV2Pool pool,
        IMaverickV2Pool.RemoveLiquidityParams memory params
    ) external onlyTokenIdAuthorizedUser(tokenId) returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        (tokenAAmount, tokenBAmount) = pool.removeLiquidity(recipient, tokenId, params);
    }

    /// @inheritdoc IMaverickV2Position
    function removeLiquidityToSender(
        uint256 tokenId,
        IMaverickV2Pool pool,
        IMaverickV2Pool.RemoveLiquidityParams memory params
    ) external onlyTokenIdAuthorizedUser(tokenId) returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        (tokenAAmount, tokenBAmount) = pool.removeLiquidity(msg.sender, tokenId, params);
    }

    /// @inheritdoc IMaverickV2Position
    function setTokenIdData(
        uint256 tokenId,
        uint256 index,
        IMaverickV2Pool pool,
        uint32[] memory binIds
    ) external onlyTokenIdAuthorizedUser(tokenId) {
        PositionPoolBinIds memory data = PositionPoolBinIds(pool, binIds);
        _checkData(data);
        dataByTokenId[tokenId][index] = data;
        _checkNoDuplicatePool(tokenId);
        emit PositionSetData(tokenId, index, data);
    }

    /// @inheritdoc IMaverickV2Position
    function setTokenIdData(
        uint256 tokenId,
        PositionPoolBinIds[] memory data
    ) external onlyTokenIdAuthorizedUser(tokenId) {
        delete dataByTokenId[tokenId];
        emit PositionClearData(tokenId);
        for (uint256 k; k < data.length; k++) {
            _checkData(data[k]);
            dataByTokenId[tokenId].push(data[k]);
            emit PositionSetData(tokenId, k, data[k]);
        }
        _checkNoDuplicatePool(tokenId);
    }

    /// @inheritdoc IMaverickV2Position
    function appendTokenIdData(
        uint256 tokenId,
        IMaverickV2Pool pool,
        uint32[] memory binIds
    ) external onlyTokenIdAuthorizedUser(tokenId) {
        PositionPoolBinIds memory data = PositionPoolBinIds(pool, binIds);
        _checkData(data);
        dataByTokenId[tokenId].push(data);
        _checkNoDuplicatePool(tokenId);
        emit PositionSetData(tokenId, dataByTokenId[tokenId].length - 1, data);
    }

    /// @inheritdoc IMaverickV2Position
    function getTokenIdData(uint256 tokenId) external view returns (PositionPoolBinIds[] memory) {
        return dataByTokenId[tokenId];
    }

    /// @inheritdoc IMaverickV2Position
    function getTokenIdData(uint256 tokenId, uint256 index) external view returns (PositionPoolBinIds memory) {
        return dataByTokenId[tokenId][index];
    }

    /// @inheritdoc IMaverickV2Position
    function tokenIdDataLength(uint256 tokenId) external view returns (uint256 length) {
        return dataByTokenId[tokenId].length;
    }

    /// @inheritdoc IMaverickV2Position
    function tokenIdPositionInformation(
        uint256 tokenId,
        uint256 startIndex,
        uint256 stopIndex
    ) public view returns (PositionFullInformation[] memory output) {
        stopIndex = Math.min(dataByTokenId[tokenId].length, stopIndex);
        uint256 count = stopIndex - startIndex;
        output = new PositionFullInformation[](count);
        for (uint256 k; k < count; k++) {
            uint256 index = k + startIndex;
            output[index] = tokenIdPositionInformation(tokenId, index);
        }
    }

    /// @inheritdoc IMaverickV2Position
    function tokenIdPositionInformation(
        uint256 tokenId,
        uint256 index
    ) public view returns (PositionFullInformation memory output) {
        output.poolBinIds = dataByTokenId[tokenId][index];
        (
            output.amountA,
            output.amountB,
            output.binAAmounts,
            output.binBAmounts,
            output.ticks,
            output.liquidities
        ) = PoolInspection.subaccountPositionInformation(
            output.poolBinIds.pool,
            address(this),
            tokenId,
            output.poolBinIds.binIds
        );
    }

    /// @inheritdoc IMaverickV2Position
    function getRemoveParams(
        uint256 tokenId,
        uint256 index,
        uint256 proportionD18
    ) public view returns (IMaverickV2Pool.RemoveLiquidityParams memory params) {
        PositionPoolBinIds memory data = dataByTokenId[tokenId][index];
        params.binIds = data.binIds;
        params.amounts = PoolInspection.binLpBalances(data.pool, params.binIds, tokenId);
        if (proportionD18 < ONE) {
            for (uint256 k; k < params.amounts.length; k++) {
                params.amounts[k] = Math.mulFloor(params.amounts[k], proportionD18).toUint128();
            }
        }
    }

    /**
     * @notice Checks that binIds are unique.
     */
    function _checkData(PositionPoolBinIds memory data) internal view {
        uint256 binCount = data.pool.getState().binCounter;
        // if not factory pool, revert
        // if permissioned liquidity, revert
        if (!factory.isFactoryPool(data.pool)) revert PositionNotFactoryPool();
        if (data.pool.permissionedLiquidity()) revert PositionPermissionedLiquidityPool();
        data.binIds.checkUnique(binCount);
    }

    /**
     * @notice Checks that token data does not contain duplicate pool.
     */
    function _checkNoDuplicatePool(uint256 tokenId) internal view {
        uint256 length = dataByTokenId[tokenId].length;
        if (length <= 1) return;
        // hold list of pools as they are pulled from storage
        IMaverickV2Pool[] memory poolList = new IMaverickV2Pool[](length);
        for (uint256 k; k < length; k++) {
            poolList[k] = dataByTokenId[tokenId][k].pool;
            for (uint256 j; j < k; j++) {
                // loop through all pools so far to compare to this new pool in the list
                if (poolList[k] == poolList[j]) revert PositionDuplicatePool(k, poolList[k]);
            }
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override(Nft, INft) returns (string memory) {
        address owner = ownerOf(tokenId);
        return positionImage.image(tokenId, owner);
    }

    function name() public view override(INft, Nft) returns (string memory) {
        return super.name();
    }

    function symbol() public view override(INft, Nft) returns (string memory) {
        return super.symbol();
    }
}
