// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {TickMath} from "@maverick/v2-common/contracts/libraries/TickMath.sol";
import {MINIMUM_LIQUIDITY} from "@maverick/v2-common/contracts/libraries/Constants.sol";

import {IMaverickV2BoostedPosition} from "./interfaces/IMaverickV2BoostedPosition.sol";
import {IMaverickV2PoolLens} from "./interfaces/IMaverickV2PoolLens.sol";
import {LiquidityUtilities} from "./libraries/LiquidityUtilities.sol";
import {PackLib} from "./libraries/PackLib.sol";

/**
 * @notice Contract that provides both views into a pool's state as well as
 * helpfer functions to compute paramters used by MaverickV2LiquidityManager.
 */
contract MaverickV2PoolLens is IMaverickV2PoolLens {
    using Cast for uint256;

    /* ++++++++++++++++++++++++++++++++++++
     * State Params
     * ++++++++++++++++++++++++++++++++++++
     */

    /// @inheritdoc IMaverickV2PoolLens
    function getAddLiquidityParams(
        AddParamsViewInputs memory params
    )
        public
        view
        returns (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        )
    {
        return LiquidityUtilities.getAddLiquidityParams(params);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getAddLiquidityParamsForBoostedPosition(
        IMaverickV2BoostedPosition boostedPosition,
        AddParamsSpecification memory addSpec
    )
        public
        view
        returns (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        )
    {
        (BoostedPositionSpecification memory spec, int32[] memory ticks) = LiquidityUtilities.getBoostedPositionSpec(
            boostedPosition
        );
        return LiquidityUtilities.getAddLiquidityParamsFromRelativeBinLpBalance(spec, ticks, addSpec);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getCreateBoostedPositionParams(
        BoostedPositionSpecification memory bpSpec,
        AddParamsSpecification memory addSpec
    )
        public
        view
        returns (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        )
    {
        uint256 length = bpSpec.ratios.length;
        int32[] memory ticks = new int32[](length);
        for (uint256 k; k < length; k++) {
            ticks[k] = bpSpec.pool.getBin(bpSpec.binIds[k]).tick;
        }
        return LiquidityUtilities.getAddLiquidityParamsFromRelativeBinLpBalance(bpSpec, ticks, addSpec);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getCreatePoolAtPriceAndAddLiquidityParams(
        CreateAndAddParamsViewInputs memory params,
        IMaverickV2Factory factory
    ) public view returns (CreateAndAddParamsInputs memory output) {
        output = _getCreatePoolParams(params, factory.protocolFeeRatioD3());
        (
            output.feeAIn,
            output.feeBIn,
            output.tickSpacing,
            output.lookback,
            output.tokenA,
            output.tokenB,
            output.activeTick,
            output.kinds
        ) = (
            params.feeAIn,
            params.feeBIn,
            params.tickSpacing,
            params.lookback,
            params.tokenA,
            params.tokenB,
            params.activeTick,
            params.kinds
        );
    }

    /* ++++++++++++++++++++++++++++++++++++
     * State Views
     * ++++++++++++++++++++++++++++++++++++
     */

    /// @inheritdoc IMaverickV2PoolLens
    function getTicksAroundActive(
        IMaverickV2Pool pool,
        int32 tickRadius
    ) public view returns (int32[] memory ticks, IMaverickV2Pool.TickState[] memory tickStates) {
        int32 activeTick = pool.getState().activeTick;
        int32 tickStart = activeTick - tickRadius;
        int32 tickEnd = activeTick + tickRadius;
        return getTicks(pool, tickStart, tickEnd);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getTicks(
        IMaverickV2Pool pool,
        int32 tickStart,
        int32 tickEnd
    ) public view returns (int32[] memory ticks, IMaverickV2Pool.TickState[] memory tickStates) {
        uint256 tickCount = uint32(tickEnd - tickStart + 1);
        tickStates = new IMaverickV2Pool.TickState[](tickCount);
        ticks = new int32[](tickCount);

        uint256 i;
        IMaverickV2Pool.TickState memory tickState;
        for (int32 k = tickStart; k <= tickEnd; k++) {
            tickState = pool.getTick(k);
            if (tickState.reserveA == 0 && tickState.reserveB == 0) continue;

            tickStates[i] = tickState;
            ticks[i] = k;
            i++;
        }

        assembly ("memory-safe") {
            mstore(tickStates, i)
            mstore(ticks, i)
        }
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getTicksAroundActiveWLiquidity(
        IMaverickV2Pool pool,
        int32 tickRadius
    )
        public
        view
        returns (
            int32[] memory ticks,
            IMaverickV2Pool.TickState[] memory tickStates,
            uint256[] memory liquidities,
            uint256[] memory sqrtLowerTickPrices,
            uint256[] memory sqrtUpperTickPrices,
            IMaverickV2Pool.State memory poolState,
            uint256 sqrtPrice,
            uint256 feeAIn,
            uint256 feeBIn
        )
    {
        poolState = pool.getState();
        (sqrtPrice, ) = getTickSqrtPriceAndL(pool, poolState.activeTick);
        int32 tickStart = poolState.activeTick - tickRadius;
        int32 tickEnd = poolState.activeTick + tickRadius;
        (ticks, tickStates, liquidities, sqrtLowerTickPrices, sqrtUpperTickPrices) = _getTicksWLiqudity(
            pool,
            tickStart,
            tickEnd
        );
        (feeAIn, feeBIn) = (pool.fee(true), pool.fee(false));
    }

    /**
     * @notice Gets ticks, liquidity, and tick edge prices in a given range.
     */
    function _getTicksWLiqudity(
        IMaverickV2Pool pool,
        int32 tickStart,
        int32 tickEnd
    )
        internal
        view
        returns (
            int32[] memory ticks,
            IMaverickV2Pool.TickState[] memory tickStates,
            uint256[] memory liquidities,
            uint256[] memory sqrtLowerTickPrices,
            uint256[] memory sqrtUpperTickPrices
        )
    {
        uint256 tickCount = uint32(tickEnd - tickStart + 1);
        tickStates = new IMaverickV2Pool.TickState[](tickCount);
        ticks = new int32[](tickCount);
        liquidities = new uint256[](tickCount);
        sqrtLowerTickPrices = new uint256[](tickCount);
        sqrtUpperTickPrices = new uint256[](tickCount);

        uint256 i;
        uint256 tickSpacing = pool.tickSpacing();
        IMaverickV2Pool.TickState memory tickState;
        for (int32 k = tickStart; k <= tickEnd; k++) {
            tickState = pool.getTick(k);
            if (tickState.reserveA == 0 && tickState.reserveB == 0) continue;

            tickStates[i] = tickState;
            ticks[i] = k;
            (sqrtLowerTickPrices[i], sqrtUpperTickPrices[i]) = TickMath.tickSqrtPrices(tickSpacing, k);
            liquidities[i] = TickMath.getTickL(
                tickStates[i].reserveA,
                tickStates[i].reserveB,
                sqrtLowerTickPrices[i],
                sqrtUpperTickPrices[i]
            );
            i++;
        }
        assembly ("memory-safe") {
            mstore(tickStates, i)
            mstore(ticks, i)
            mstore(sqrtLowerTickPrices, i)
            mstore(sqrtUpperTickPrices, i)
            mstore(liquidities, i)
        }
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getFullPoolState(
        IMaverickV2Pool pool,
        uint32 binStart,
        uint32 binEnd
    ) public view returns (PoolState memory poolState) {
        poolState.state = pool.getState();
        binEnd = poolState.state.binCounter < binEnd ? poolState.state.binCounter : binEnd;
        uint128 bincount = binEnd - binStart + 1;
        poolState.binStateMapping = new IMaverickV2Pool.BinState[](bincount);
        poolState.tickStateMapping = new IMaverickV2Pool.TickState[](bincount);
        poolState.binIdByTickKindMapping = new BinPositionKinds[](bincount);
        poolState.protocolFees = Reserves(pool.protocolFeeA(), pool.protocolFeeB());

        for (uint32 i = 0; i < bincount; i++) {
            poolState.binStateMapping[i] = pool.getBin(i + binStart);
            poolState.tickStateMapping[i] = pool.getTick(poolState.binStateMapping[i].tick);
            for (uint8 kind; kind < 4; kind++) {
                poolState.binIdByTickKindMapping[i].values[kind] = pool.binIdByTickKind(
                    poolState.binStateMapping[i].tick,
                    kind
                );
            }
        }
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getTickSqrtPriceAndL(
        IMaverickV2Pool pool,
        int32 tick
    ) public view returns (uint256 sqrtPrice, uint256 liquidity) {
        uint256 tickSpacing = pool.tickSpacing();
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(tickSpacing, tick);
        IMaverickV2Pool.TickState memory tickState = pool.getTick(tick);

        (sqrtPrice, liquidity) = TickMath.getTickSqrtPriceAndL(
            tickState.reserveA,
            tickState.reserveB,
            sqrtLowerTickPrice,
            sqrtUpperTickPrice
        );
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getPoolSqrtPrice(IMaverickV2Pool pool) public view returns (uint256 sqrtPrice) {
        int32 tick = pool.getState().activeTick;
        (sqrtPrice, ) = getTickSqrtPriceAndL(pool, tick);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function getPoolPrice(IMaverickV2Pool pool) public view returns (uint256 price) {
        uint256 sqrtPrice = getPoolSqrtPrice(pool);
        price = Math.mulFloor(sqrtPrice, sqrtPrice);
    }

    /// @inheritdoc IMaverickV2PoolLens
    function tokenScales(IMaverickV2Pool pool) public view returns (uint256 tokenAScale, uint256 tokenBScale) {
        tokenAScale = pool.tokenAScale();
        tokenBScale = pool.tokenBScale();
    }

    function _getCreatePoolParams(
        CreateAndAddParamsViewInputs memory params,
        uint256 protocolFeeRatio
    ) internal view returns (CreateAndAddParamsInputs memory output) {
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(
            params.tickSpacing,
            params.activeTick
        );
        LiquidityUtilities.RelativeLiquidityInput memory input;
        LiquidityUtilities.StateInfo memory existingState;

        input.poolTickSpacing = params.tickSpacing;
        input.tokenAScale = Math.scale(IERC20Metadata(address(params.tokenA)).decimals());
        input.tokenBScale = Math.scale(IERC20Metadata(address(params.tokenB)).decimals());
        input.ticks = params.ticks;
        input.relativeLiquidityAmounts = params.relativeLiquidityAmounts;
        input.targetAmount = params.targetAmount;
        input.targetIsA = params.targetIsA;
        existingState.activeTick = params.activeTick;

        output.donateParams.ticks = new int32[](1);
        output.donateParams.ticks[0] = params.activeTick;
        output.donateParams.amounts = new uint128[](1);
        if (sqrtLowerTickPrice != params.sqrtPrice) {
            // target price is not tick edge, need to dontate/swap
            (output.donateParams.amounts[0], output.swapAmount) = LiquidityUtilities.donateAndSwapData(
                params.tickSpacing,
                params.activeTick,
                params.feeAIn,
                params.tokenB,
                params.initialTargetB,
                params.sqrtPrice
            );

            if (output.donateParams.amounts[0] < MINIMUM_LIQUIDITY)
                revert LiquidityUtilities.LiquidityUtilitiesInitialTargetBTooSmall(
                    params.initialTargetB,
                    output.donateParams.amounts[0],
                    MINIMUM_LIQUIDITY
                );
            existingState.binTotalSupply = output.donateParams.amounts[0] + MINIMUM_LIQUIDITY;

            existingState.reserveB = Math.tokenScaleToAmmScale(
                params.initialTargetB - output.swapAmount,
                input.tokenBScale
            );
            existingState.reserveA = LiquidityUtilities.emulateExactOut(
                Math.tokenScaleToAmmScale(output.swapAmount, input.tokenBScale),
                Math.tokenScaleToAmmScale(params.initialTargetB, input.tokenBScale),
                sqrtLowerTickPrice,
                sqrtUpperTickPrice,
                params.feeAIn,
                protocolFeeRatio
            );

            (input.newSqrtPrice, ) = TickMath.getTickSqrtPriceAndL(
                existingState.reserveA,
                existingState.reserveB,
                sqrtLowerTickPrice,
                sqrtUpperTickPrice
            );
        } else {
            input.newSqrtPrice = sqrtLowerTickPrice;
        }

        {
            (IMaverickV2PoolLens.TickDeltas memory tickDeltas, bool success) = LiquidityUtilities
                ._deltasFromRelativeBinLiquidityAmountsAndTargetAmount(input);
            if (!success) revert LiquidityUtilities.LiquidityUtilitiesFailedToFindDeltaAmounts();

            output.addParams = LiquidityUtilities.lpBalanceForArrayOfTargetAmountsEmptyPool(
                tickDeltas,
                input,
                existingState,
                params.kind
            );
            output.packedAddParams = PackLib.packAddLiquidityArgsToArray(output.addParams);
            output.deltaAOut = tickDeltas.deltaAOut;
            output.deltaBOut = tickDeltas.deltaBOut;
            output.preAddReserveA = existingState.reserveA;
            output.preAddReserveB = existingState.reserveB;
        }
    }
}
