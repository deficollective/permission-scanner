// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {EMPTY_PRICE_BREAKS} from "@maverick/v2-common/contracts/libraries/Constants.sol";

import {PoolInspection} from "./libraries/PoolInspection.sol";
import {IMaverickV2Position} from "./interfaces/IMaverickV2Position.sol";
import {IMaverickV2PoolLens} from "./interfaces/IMaverickV2PoolLens.sol";
import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {IMaverickV2LiquidityManager} from "./interfaces/IMaverickV2LiquidityManager.sol";
import {IMaverickV2BoostedPositionFactory} from "./interfaces/IMaverickV2BoostedPositionFactory.sol";
import {IWETH9} from "./paymentbase/IWETH9.sol";
import {ArgPacker} from "./liquiditybase/ArgPacker.sol";
import {State} from "./paymentbase/State.sol";
import {ExactOutputSlim} from "./routerbase/ExactOutputSlim.sol";
import {LiquidityUtilities} from "./libraries/LiquidityUtilities.sol";
import {Checks} from "./base/Checks.sol";
import {MigrateBins} from "./base/MigrateBins.sol";

/**
 * @notice Maverick liquidity management contract that provides helper
 * functions for minting either NFT liquidity positions or boosted positions
 * which are fungible positions in a Maverick V2 pool.  While this contract
 * does have public payment callback functions, these are access controlled
 * so that they can only be called by a factory pool; so it is safe to approve
 * this contract to spend a caller's tokens.
 *
 * This contract inherits "Check" functions that can be multicalled with
 * liquidity management functions to create slippage and deadline constraints on
 * transactions.
 *
 *
 * @dev This contract has a multicall interface and all public functions are
 * payable which facilitates multicall combinations of both payable
 * interactions and non-payable interactions.
 *
 * @dev addLiquidity parameters are specified as a lookup table of prices where
 * the caller specifies packedSqrtPriceBreaks and packedArgs.  During the add
 * operation, this contract queries the pool for its current sqrtPrice and then
 * looks up this price relative to the price breaks array (the array is packed
 * as bytes using the conventions in the inherited ArgPacker contract to save
 * calldata space).  If the current pool sqrt price is in between the N and N+1
 * elements of the packedSqrtPriceBreaks array, then the add parameters from the
 * Nth element of the packedArgs array are used in the add liquidity call.
 *
 * @dev This lookup table approach provides a flexible way for callers to
 * manage price slippage between the time they submit their transaction and the
 * time it is executed. The MaverickV2PoolLens contract provides a number of
 * helper function to create this slippage lookup table.
 */
contract MaverickV2LiquidityManager is Checks, ExactOutputSlim, ArgPacker, MigrateBins, IMaverickV2LiquidityManager {
    /// @inheritdoc IMaverickV2LiquidityManager
    IMaverickV2Position public immutable position;

    /// @inheritdoc IMaverickV2LiquidityManager
    IMaverickV2BoostedPositionFactory public immutable boostedPositionFactory;

    constructor(
        IMaverickV2Factory _factory,
        IWETH9 _weth,
        IMaverickV2Position _position,
        IMaverickV2BoostedPositionFactory _boostedPositionFactory
    ) State(_factory, _weth) {
        position = _position;
        boostedPositionFactory = _boostedPositionFactory;
    }

    ///////////////////////////
    ////  Pool functions
    ///////////////////////////

    /// @inheritdoc IMaverickV2LiquidityManager
    function createPool(
        uint64 fee,
        uint16 tickSpacing,
        uint32 lookback,
        IERC20 tokenA,
        IERC20 tokenB,
        int32 activeTick,
        uint8 kinds
    ) public payable returns (IMaverickV2Pool pool) {
        pool = factory().create(fee, fee, tickSpacing, lookback, tokenA, tokenB, activeTick, kinds);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function createPool(
        uint64 feeAIn,
        uint64 feeBIn,
        uint16 tickSpacing,
        uint32 lookback,
        IERC20 tokenA,
        IERC20 tokenB,
        int32 activeTick,
        uint8 kinds
    ) public payable returns (IMaverickV2Pool pool) {
        pool = factory().create(feeAIn, feeBIn, tickSpacing, lookback, tokenA, tokenB, activeTick, kinds);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function addLiquidity(
        IMaverickV2Pool pool,
        address recipient,
        uint256 subaccount,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds) {
        uint256 sqrtPrice = PoolInspection.poolSqrtPrice(pool);

        uint256 priceIndex = LiquidityUtilities.priceIndexFromPriceBreaks(sqrtPrice, packedSqrtPriceBreaks);
        IMaverickV2Pool.AddLiquidityParams memory args = unpackAddLiquidityArgs(packedArgs[priceIndex]);
        (tokenAAmount, tokenBAmount, binIds) = pool.addLiquidity(recipient, subaccount, args, abi.encode(msg.sender));
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function donateLiquidity(IMaverickV2Pool pool, IMaverickV2Pool.AddLiquidityParams memory args) public payable {
        pool.addLiquidity(address(position), 0, args, abi.encode(msg.sender));
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function createPoolAtPriceAndAddLiquidityToSender(
        IMaverickV2PoolLens.CreateAndAddParamsInputs memory params
    )
        public
        payable
        returns (
            IMaverickV2Pool pool,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint32[] memory binIds,
            uint256 tokenId
        )
    {
        return createPoolAtPriceAndAddLiquidity(msg.sender, params);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function createPoolAtPriceAndAddLiquidity(
        address recipient,
        IMaverickV2PoolLens.CreateAndAddParamsInputs memory params
    )
        public
        payable
        returns (
            IMaverickV2Pool pool,
            uint256 tokenAAmount,
            uint256 tokenBAmount,
            uint32[] memory binIds,
            uint256 tokenId
        )
    {
        pool = createPool(
            params.feeAIn,
            params.feeBIn,
            params.tickSpacing,
            params.lookback,
            params.tokenA,
            params.tokenB,
            params.activeTick,
            params.kinds
        );
        if (params.swapAmount != 0) {
            donateLiquidity(pool, params.donateParams);
            exactOutputSingleMinimal(recipient, pool, true, params.swapAmount, type(int32).max);
        }

        (tokenAAmount, tokenBAmount, binIds, tokenId) = mintPositionNft(
            pool,
            recipient,
            EMPTY_PRICE_BREAKS,
            params.packedAddParams
        );
    }

    function maverickV2AddLiquidityCallback(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amountA,
        uint256 amountB,
        bytes calldata data
    ) public {
        if (!factory().isFactoryPool(IMaverickV2Pool(msg.sender))) revert LiquidityManagerNotFactoryPool();
        address payer = abi.decode(data, (address));
        if (amountA != 0) {
            pay(tokenA, payer, msg.sender, amountA);
        }
        if (amountB != 0) {
            pay(tokenB, payer, msg.sender, amountB);
        }
    }

    ///////////////////////////
    ////  Position NFT functions
    ///////////////////////////

    /// @inheritdoc IMaverickV2LiquidityManager
    function addPositionLiquidityToSenderByTokenIndex(
        IMaverickV2Pool pool,
        uint256 index,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds) {
        (tokenAAmount, tokenBAmount, binIds) = addLiquidity(
            pool,
            address(position),
            position.tokenOfOwnerByIndex(msg.sender, index),
            packedSqrtPriceBreaks,
            packedArgs
        );
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function addPositionLiquidityToRecipientByTokenIndex(
        IMaverickV2Pool pool,
        address recipient,
        uint256 index,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds) {
        (tokenAAmount, tokenBAmount, binIds) = addLiquidity(
            pool,
            address(position),
            position.tokenOfOwnerByIndex(recipient, index),
            packedSqrtPriceBreaks,
            packedArgs
        );
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function mintPositionNft(
        IMaverickV2Pool pool,
        address recipient,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds, uint256 tokenId) {
        (tokenAAmount, tokenBAmount, binIds) = addLiquidity(
            pool,
            address(position),
            position.nextTokenId(),
            packedSqrtPriceBreaks,
            packedArgs
        );
        tokenId = position.mint(recipient, pool, binIds);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function mintPositionNftToSender(
        IMaverickV2Pool pool,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds, uint256 tokenId) {
        return mintPositionNft(pool, msg.sender, packedSqrtPriceBreaks, packedArgs);
    }

    ///////////////////////////
    ////  Booste Position functions
    ///////////////////////////

    /// @inheritdoc IMaverickV2LiquidityManager
    function migrateBoostedPosition(IMaverickV2BoostedPosition boostedPosition) public payable {
        boostedPosition.migrateBinLiquidityToRoot();
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function skimBoostedPosition(
        IMaverickV2BoostedPosition boostedPosition,
        address recipient
    ) public payable returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        (tokenAAmount, tokenBAmount) = boostedPosition.skim(recipient);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function mintBoostedPosition(
        IMaverickV2BoostedPosition boostedPosition,
        address recipient
    ) public payable returns (uint256 mintedLpAmount) {
        mintedLpAmount = boostedPosition.mint(recipient);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function addLiquidityAndMintBoostedPosition(
        address recipient,
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable virtual returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount) {
        boostedPosition.migrateBinLiquidityToRoot();
        if (boostedPosition.skimmableAmount() != 0) skimBoostedPosition(boostedPosition, recipient);
        (tokenAAmount, tokenBAmount, ) = addLiquidity(
            boostedPosition.pool(),
            address(boostedPosition),
            0,
            packedSqrtPriceBreaks,
            packedArgs
        );
        mintedLpAmount = boostedPosition.mint(recipient);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function addLiquidityAndMintBoostedPositionToSender(
        IMaverickV2BoostedPosition boostedPosition,
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs
    ) public payable returns (uint256 mintedLpAmount, uint256 tokenAAmount, uint256 tokenBAmount) {
        return addLiquidityAndMintBoostedPosition(msg.sender, boostedPosition, packedSqrtPriceBreaks, packedArgs);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function createBoostedPositionAndAddLiquidityToSender(
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params
    )
        public
        payable
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount
        )
    {
        return createBoostedPositionAndAddLiquidity(msg.sender, params);
    }

    /// @inheritdoc IMaverickV2LiquidityManager
    function createBoostedPositionAndAddLiquidity(
        address recipient,
        IMaverickV2PoolLens.CreateBoostedPositionInputs memory params
    )
        public
        payable
        virtual
        returns (
            IMaverickV2BoostedPosition boostedPosition,
            uint256 mintedLpAmount,
            uint256 tokenAAmount,
            uint256 tokenBAmount
        )
    {
        boostedPosition = boostedPositionFactory.createBoostedPosition(
            params.bpSpec.pool,
            params.bpSpec.binIds,
            params.bpSpec.ratios,
            params.bpSpec.kind
        );
        (tokenAAmount, tokenBAmount, ) = addLiquidity(
            params.bpSpec.pool,
            address(boostedPosition),
            0,
            params.packedSqrtPriceBreaks,
            params.packedArgs
        );
        mintedLpAmount = boostedPosition.mint(recipient);
    }
}
