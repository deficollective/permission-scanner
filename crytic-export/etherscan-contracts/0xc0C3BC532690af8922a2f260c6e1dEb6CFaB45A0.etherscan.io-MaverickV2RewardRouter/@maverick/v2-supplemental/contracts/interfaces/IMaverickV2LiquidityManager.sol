// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {IMaverickV2Position} from "./IMaverickV2Position.sol";
import {IMaverickV2BoostedPosition} from "./IMaverickV2BoostedPosition.sol";
import {IMaverickV2PoolLens} from "./IMaverickV2PoolLens.sol";
import {IMaverickV2BoostedPositionFactory} from "./IMaverickV2BoostedPositionFactory.sol";
import {IArgPacker} from "../liquiditybase/IArgPacker.sol";
import {IExactOutputSlim} from "../routerbase/IExactOutputSlim.sol";
import {IPayment} from "../paymentbase/IPayment.sol";
import {IChecks} from "../base/IChecks.sol";
import {IMigrateBins} from "../base/IMigrateBins.sol";

interface IMaverickV2LiquidityManager is IPayment, IChecks, IExactOutputSlim, IArgPacker, IMigrateBins {
    error LiquidityManagerNotFactoryPool();
    error LiquidityManagerNotTokenIdOwner();

    /**
     * @notice Maverick V2 NFT position contract that tracks NFT-based
     * liquditiy positions.
     */
    function position() external view returns (IMaverickV2Position);

    /**
     * @notice Maverick V2 BP factory contract.
     */
    function boostedPositionFactory() external view returns (IMaverickV2BoostedPositionFactory);

    /**
     * @notice Create Maverick V2 pool.  Function is a pass through to the pool
     * factory and is provided here so that is can be assembled as part of a
     * multicall transaction.
     */
    function createPool(
        uint64 fee,
        uint16 tickSpacing,
        uint32 lookback,
        IERC20 tokenA,
        IERC20 tokenB,
        int32 activeTick,
        uint8 kinds
    ) external payable returns (IMaverickV2Pool pool);

    /**
     * @notice Create Maverick V2 pool with two-way fees.  Function is a pass
     * through to the pool factory and is provided here so that is can be
     * assembled as part of a multicall transaction.
     */
    function createPool(
        uint64 feeAIn,
        uint64 feeBIn,
        uint16 tickSpacing,
        uint32 lookback,
        IERC20 tokenA,
        IERC20 tokenB,
        int32 activeTick,
        uint8 kinds
    ) external payable returns (IMaverickV2Pool pool);

    /**
     * @notice Add Liquidity to a Maverick V2 pool.  Function is a pass through
     * to the pool and is provided here so that is can be assembled as part of a
     * multicall transaction.  Users can add liquidity to the Position NFT
     * contract or a BP as part of a multicall in order to mint NFT/BP
     * positions.
     * @dev Liquidity is specified as bytes that represent a lookup table of
     * add parameters.  This allows an adder to specify what liquidity amounts
     * they wish to add conditional on the price of the pool when their
     * transaction is executed.  With this, users have fine-grain control of how
     * price slippage affects the amount of liquidity they add.  The
     * MaverickV2PoolLens contract has helper view functions that can be used
     * to easily create a combination of price breaks and packed arguments.
     */
    function addLiquidity(
        IMaverickV2Pool pool,
        address recipient,
        uint256 subaccount,
        bytes calldata packedSqrtPriceBreaks,
        bytes[] calldata packedArgs
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds);

    /**
     * @notice Add Liquidity position NFT for msg.sender by specifying
     * msg.sender's token index.
     * @dev Token index is different from tokenId.
     * On the Position NFT contract a user can own multiple NFT tokenIds and
     * these are indexes by an enumeration index which is the `index` input
     * here.
     *
     * See addLiquidity for a description of the add params.
     */
    function addPositionLiquidityToSenderByTokenIndex(
        IMaverickV2Pool pool,
        uint256 index,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds);

    /**
     * @notice Add Liquidity position NFT for msg.sender by specifying
     * recipient's token index.
     * @dev Token index is different from tokenId.
     * On the Position NFT contract a user can own multiple NFT tokenIds and
     * these are indexes by an enumeration index which is the `index` input
     * here.
     *
     * See addLiquidity for a description of the add params.
     */
    function addPositionLiquidityToRecipientByTokenIndex(
        IMaverickV2Pool pool,
        address recipient,
        uint256 index,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds);

    /**
     * @notice Pass through function to the BP bin migration.
     */
    function migrateBoostedPosition(IMaverickV2BoostedPosition boostedPosition) external payable;

    /**
     * @notice Mint new tokenId in the Position NFT contract. Both mints an NFT
     * and adds liquidity to the pool that is held by the NFT.
     * @dev Caller must approve this LiquidityManager contract to spend the
     * caller's token A/B in order to fund the liquidity position.
     *
     * See addLiquidity for a description of the add params.
     */
    function mintPositionNft(
        IMaverickV2Pool pool,
        address recipient,
        bytes calldata packedSqrtPriceBreaks,
        bytes[] calldata packedArgs
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds, uint256 tokenId);

    /**
     * @notice Mint new tokenId in the Position NFt contract to msg.sender.
     * Both mints an NFT and adds liquidity to the pool that is held by the
     * NFT.
     */
    function mintPositionNftToSender(
        IMaverickV2Pool pool,
        bytes calldata packedSqrtPriceBreaks,
        bytes[] calldata packedArgs
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds, uint256 tokenId);

    /**
     * @notice Mint BP LP tokens to recipient.  This function does not add
     * liquidity to the BP and is only useful in conjuction with addLiquidity
     * as part of a multcall.
     */
    function mintBoostedPosition(
        IMaverickV2BoostedPosition boostedPosition,
        address recipient
    ) external payable returns (uint256 mintedLpAmount);

    /**
     * @notice Donates liqudity to a pool that is held by the position contract
     * and will never be retrievable.  Can be used to start a pool and ensure
     * there will always be a base level of liquditiy in the pool.
     */
    function donateLiquidity(IMaverickV2Pool pool, IMaverickV2Pool.AddLiquidityParams memory args) external payable;

    /**
     * @notice Creates a pool at a specified price and mints a Position NFT
     * with liquidity to the recipient.
     * @dev A Maverick V2 pool has no native was to specify a starting price,
     * only a starting `activeTick`.  The initial pool price will be the left
     * edge of the initial activeTick.  In order to create a pool at a fixed
     * price, this function dontes a small amount of liquidity to the pool, does
     * a swap to the specified price, and then adds liquidity for the user.
     */
    function createPoolAtPriceAndAddLiquidity(
        address recipient,
        IMaverickV2PoolLens.CreateAndAddParamsInputs memory params
    )
        external
        payable
        returns (
            IMaverickV2Pool pool,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint32[] memory binIds,
            uint256 tokenId
        );

    /**
     * @notice Creates a pool at a specified price and mints a Position NFT
     * with liquidity to msg.sender.
     */
    function createPoolAtPriceAndAddLiquidityToSender(
        IMaverickV2PoolLens.CreateAndAddParamsInputs memory params
    )
        external
        payable
        returns (
            IMaverickV2Pool pool,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint32[] memory binIds,
            uint256 tokenId
        );

    /**
     * @notice Executes the multi-step process of minting BP LP positions by
     * adding liqudiity to a pool in the BP liquidity distribution and then
     * minting the BP to recipient.
     * @dev Caller will need to approve this LiquidityManager contract to spend
     * their token A/B in order to execute this function.
     */
    function addLiquidityAndMintBoostedPosition(
        address recipient,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) external payable returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount);

    /**
     * @notice Executes the multi-step process of minting BP LP positions by
     * adding liquidity to a pool in the BP liquidity distribution and then
     * minting the BP to msg.sender.
     * @dev Caller will need to approve this LiquidityManager contract to spend
     * their token A/B in order to execute this function.
     */
    function addLiquidityAndMintBoostedPositionToSender(
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) external payable returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount);

    /**
     * @notice Deploy new BP contract from the BP factory and mint BP LP tokens
     * to the recipient.
     * @dev Caller will need to approve this LiquidityManager contract to spend
     * their token A/B in order to execute this function.
     */
    function createBoostedPositionAndAddLiquidity(
        address recipient,
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params
    )
        external
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount
        );

    /**
     * @notice Deploy new BP contract from the BP factory and mint BP LP tokens
     * to msg.sender.
     * @dev Caller will need to approve this LiquidityManager contract to spend
     * their token A/B in order to execute this function.
     */
    function createBoostedPositionAndAddLiquidityToSender(
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params
    )
        external
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount
        );

    /**
     * @notice Skims excess liquidity in a BP to the recipient.
     */
    function skimBoostedPosition(
        IMaverickV2BoostedPosition boostedPosition,
        address recipient
    ) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount);
}
