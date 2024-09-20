// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";
import {PoolLib} from "@maverick/v2-common/contracts/libraries/PoolLib.sol";
import {ONE, MINIMUM_LIQUIDITY} from "@maverick/v2-common/contracts/libraries/Constants.sol";
import {TickMath} from "@maverick/v2-common/contracts/libraries/TickMath.sol";

import {IMaverickV2PoolLens} from "../interfaces/IMaverickV2PoolLens.sol";
import {IMaverickV2BoostedPosition} from "../interfaces/IMaverickV2BoostedPosition.sol";
import {PoolInspection} from "../libraries/PoolInspection.sol";
import {PackLib} from "../libraries/PackLib.sol";

library LiquidityUtilities {
    using Cast for uint256;

    error LiquidityUtilitiesTargetPriceOutOfBounds(
        uint256 targetSqrtPrice,
        uint256 sqrtLowerTickPrice,
        uint256 sqrtUpperTickPrice
    );
    error LiquidityUtilitiesTooLittleLiquidity(uint256 relativeLiquidityAmount, uint256 deltaA, uint256 deltaB);
    error LiquidityUtilitiesTargetingTokenWithNoDelta(bool targetIsA, uint256 deltaA, uint256 deltaB);
    error LiquidityUtilitiesNoSwapLiquidity();
    error LiquidityUtilitiesFailedToFindDeltaAmounts();
    error LiquidityUtilitiesInitialTargetBTooSmall(
        uint256 initialTargetB,
        uint256 deltaLpBalance,
        uint256 minimumRequiredLpBalance
    );

    uint256 internal constant MIN_DELTA_RESERVES = 100;

    /**
     *
     * @notice Return index into the price breaks array that corresponds to the
     * current pool price.
     *
     * @dev Price break array is N elements [e_0, e_1, ..., e_{n-1}].
     * @dev If price is less than e_0, then `0` is returned, if price is
     * betweeen e_0 and e_1, then `1` is returned, etc.  If the price is
     * between e_{n-2} and e_{n-1}, then n-2 is returned.  If price is larger
     * than e_{n-1}, then n-1 is returned.
     *
     */
    function priceIndexFromPriceBreaks(
        uint256 sqrtPrice,
        bytes memory packedSqrtPriceBreaks
    ) internal pure returns (uint256 index) {
        // index is zero if the pricebreaks array only has one price
        if (packedSqrtPriceBreaks.length == 12) return index;
        uint88[] memory breaks = PackLib.unpackUint88Array(packedSqrtPriceBreaks);

        // loop terminates with `breaks.length - 1` as the max value.
        for (; index < breaks.length - 1; index++) {
            if (sqrtPrice <= breaks[index]) break;
        }
    }

    function tokenScales(IMaverickV2Pool pool) internal view returns (uint256 tokenAScale, uint256 tokenBScale) {
        tokenAScale = pool.tokenAScale();
        tokenBScale = pool.tokenBScale();
    }

    function deltaReservesFromDeltaLpBalanceAtNewPrice(
        IMaverickV2Pool pool,
        int32 tick,
        uint128 deltaLpBalance,
        uint8 kind,
        uint256 newSqrtPrice
    ) internal view returns (uint256 deltaA, uint256 deltaB) {
        PoolLib.AddLiquidityInfo memory addLiquidityInfo;
        uint32 binId = pool.binIdByTickKind(tick, kind);
        IMaverickV2Pool.BinState memory bin = pool.getBin(binId);

        addLiquidityInfo.tickSpacing = pool.tickSpacing();
        addLiquidityInfo.tick = tick;

        IMaverickV2Pool.TickState memory tickState;
        (tickState, addLiquidityInfo.tickLtActive, ) = reservesInTickForGivenPrice(pool, tick, newSqrtPrice);

        PoolLib.deltaTickBalanceFromDeltaLpBalance(
            bin.tickBalance,
            bin.totalSupply,
            tickState,
            deltaLpBalance,
            addLiquidityInfo
        );
        (uint256 tokenAScale, uint256 tokenBScale) = tokenScales(pool);
        deltaA = Math.ammScaleToTokenScale(addLiquidityInfo.deltaA, tokenAScale, true);
        deltaB = Math.ammScaleToTokenScale(addLiquidityInfo.deltaB, tokenBScale, true);
    }

    function deltaReservesFromDeltaLpBalancesAtNewPrice(
        IMaverickV2Pool pool,
        IMaverickV2Pool.AddLiquidityParams memory addParams,
        uint256 newSqrtPrice
    ) internal view returns (IMaverickV2PoolLens.TickDeltas memory tickDeltas) {
        uint256 length = addParams.ticks.length;
        tickDeltas.deltaAs = new uint256[](length);
        tickDeltas.deltaBs = new uint256[](length);
        for (uint256 k; k < length; k++) {
            (tickDeltas.deltaAs[k], tickDeltas.deltaBs[k]) = deltaReservesFromDeltaLpBalanceAtNewPrice(
                pool,
                addParams.ticks[k],
                addParams.amounts[k],
                addParams.kind,
                newSqrtPrice
            );
            tickDeltas.deltaAOut += tickDeltas.deltaAs[k];
            tickDeltas.deltaBOut += tickDeltas.deltaBs[k];
        }
    }

    function scaleAddParams(
        IMaverickV2Pool.AddLiquidityParams memory addParams,
        uint128[] memory ratios,
        uint256 addAmount,
        uint256 targetAmount
    ) internal pure returns (IMaverickV2Pool.AddLiquidityParams memory addParamsScaled) {
        uint256 length = addParams.ticks.length;
        addParamsScaled.ticks = addParams.ticks;
        addParamsScaled.kind = addParams.kind;

        addParamsScaled.amounts = new uint128[](length);

        addParamsScaled.amounts[0] = Math.mulDivFloor(addParams.amounts[0], targetAmount, addAmount).toUint128();
        for (uint256 k = 1; k < length; k++) {
            addParamsScaled.amounts[k] = Math.mulCeil(addParamsScaled.amounts[0], ratios[k]).toUint128();
        }
    }

    function getScaledAddParams(
        IMaverickV2Pool pool,
        IMaverickV2Pool.AddLiquidityParams memory addParams,
        uint128[] memory ratios,
        uint256 newSqrtPrice,
        uint256 targetAmount,
        bool targetIsA
    )
        internal
        view
        returns (
            IMaverickV2Pool.AddLiquidityParams memory addParamsScaled,
            IMaverickV2PoolLens.TickDeltas memory tickDeltas
        )
    {
        // find A and B amount for input addParams
        tickDeltas = deltaReservesFromDeltaLpBalancesAtNewPrice(pool, addParams, newSqrtPrice);
        uint256 unScaledAmount = targetIsA ? tickDeltas.deltaAOut : tickDeltas.deltaBOut;
        if (unScaledAmount == 0) revert LiquidityUtilitiesFailedToFindDeltaAmounts();

        // scale addParams to meet the delta target
        addParamsScaled = scaleAddParams(
            addParams,
            ratios,
            targetIsA ? tickDeltas.deltaAOut : tickDeltas.deltaBOut,
            targetAmount
        );
        tickDeltas = deltaReservesFromDeltaLpBalancesAtNewPrice(pool, addParamsScaled, newSqrtPrice);
    }

    function getAddLiquidityParamsFromRelativeBinLpBalance(
        IMaverickV2PoolLens.BoostedPositionSpecification memory spec,
        int32[] memory ticks,
        IMaverickV2PoolLens.AddParamsSpecification memory params
    )
        internal
        view
        returns (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        )
    {
        uint256 length = params.numberOfPriceBreaksPerSide * 2 + 1;
        addParams = new IMaverickV2Pool.AddLiquidityParams[](length);
        tickDeltas = new IMaverickV2PoolLens.TickDeltas[](length);

        uint256 sqrtPrice = PoolInspection.poolSqrtPrice(spec.pool);
        addParams[params.numberOfPriceBreaksPerSide].ticks = ticks;
        addParams[params.numberOfPriceBreaksPerSide].amounts = spec.ratios;
        addParams[params.numberOfPriceBreaksPerSide].kind = spec.kind;
        (
            addParams[params.numberOfPriceBreaksPerSide],
            tickDeltas[params.numberOfPriceBreaksPerSide]
        ) = getScaledAddParams(
            spec.pool,
            addParams[params.numberOfPriceBreaksPerSide],
            spec.ratios,
            sqrtPrice,
            params.targetAmount,
            params.targetIsA
        );

        sqrtPriceBreaks = new uint88[](length);
        sqrtPriceBreaks[params.numberOfPriceBreaksPerSide] = sqrtPrice.toUint88();

        // left of price,
        for (uint256 k; k < params.numberOfPriceBreaksPerSide; k++) {
            params.targetIsA = false;
            params.targetAmount = Math.mulDown(tickDeltas[params.numberOfPriceBreaksPerSide].deltaBOut, 0.99999e18);
            if (params.targetAmount == 0) continue;

            // price / (factor + 1), price / (factor * (n-1) / n + 1), price / (factor * (n-2)/n + 1)...
            uint256 factor = Math.mulDivFloor(
                params.slippageFactorD18,
                params.numberOfPriceBreaksPerSide - k,
                params.numberOfPriceBreaksPerSide
            );
            sqrtPriceBreaks[k] = Math.divCeil(sqrtPrice, factor + ONE).toUint88();

            (addParams[k], tickDeltas[k]) = getScaledAddParams(
                spec.pool,
                addParams[params.numberOfPriceBreaksPerSide],
                spec.ratios,
                sqrtPriceBreaks[k],
                params.targetAmount,
                params.targetIsA
            );
        }

        // right of price
        for (uint256 k; k < params.numberOfPriceBreaksPerSide; k++) {
            uint256 index = params.numberOfPriceBreaksPerSide + k + 1;
            params.targetIsA = true;
            params.targetAmount = Math.mulDown(tickDeltas[params.numberOfPriceBreaksPerSide].deltaAOut, 0.99999e18);
            if (params.targetAmount == 0) {
                sqrtPriceBreaks[index - 1] = type(uint88).max;
                break;
            }

            {
                // price * (factor * (1 / n) + 1), price * (factor * (2 / n) + 1), price / (factor * (3 / n) + 1)...
                uint256 factor = Math.mulDivFloor(params.slippageFactorD18, k + 1, params.numberOfPriceBreaksPerSide);
                sqrtPriceBreaks[index] = Math.mulCeil(sqrtPrice, factor + ONE).toUint88();
            }
            (addParams[index], tickDeltas[index]) = getScaledAddParams(
                spec.pool,
                addParams[params.numberOfPriceBreaksPerSide],
                spec.ratios,
                sqrtPriceBreaks[index],
                params.targetAmount,
                params.targetIsA
            );
        }
        sortAddParamsArray(addParams, tickDeltas);
        packedArgs = PackLib.packAddLiquidityArgsArray(addParams);
        packedSqrtPriceBreaks = PackLib.packArray(sqrtPriceBreaks);
    }

    /** @notice Compute add params for N price breaks around price with max right
     * slippage of p * (1 + f) and max left slippage of p / (1 + f).
     *
     * The user specifies the max A and B they are willing to spend.  If the
     * price of the pool does not move, the user will spend exactly this
     * amount. If the price moves left, then the user would like to spend the
     * specified B amount, but will end up spending less A.  Conversely, if the
     * price moves right, the user will spend their max A amount, but less B.
     *
     * By having more break points, we make it so that the user gets as much
     * liquidity as possible at the new price. With too few break points, the
     * user will not have bought as much liquidity as they could have.
     */
    function getAddLiquidityParams(
        IMaverickV2PoolLens.AddParamsViewInputs memory params
    )
        internal
        view
        returns (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        )
    {
        RelativeLiquidityInput memory input;

        input.poolTickSpacing = params.pool.tickSpacing();
        (input.tokenAScale, input.tokenBScale) = tokenScales(params.pool);
        input.ticks = params.ticks;
        input.relativeLiquidityAmounts = params.relativeLiquidityAmounts;

        uint256 length = params.addSpec.numberOfPriceBreaksPerSide * 2 + 1;
        addParams = new IMaverickV2Pool.AddLiquidityParams[](length);
        tickDeltas = new IMaverickV2PoolLens.TickDeltas[](length);

        // initially target the bigger amount at pool price
        input.targetIsA = params.addSpec.targetIsA;
        input.targetAmount = params.addSpec.targetAmount;
        uint256 startingPrice = PoolInspection.poolSqrtPrice(params.pool);

        input.newSqrtPrice = startingPrice;
        bool success;
        (
            addParams[params.addSpec.numberOfPriceBreaksPerSide],
            tickDeltas[params.addSpec.numberOfPriceBreaksPerSide],
            success
        ) = lpBalanceForArrayOfTargetAmounts(input, params.pool, params.kind);
        if (!success) revert LiquidityUtilitiesFailedToFindDeltaAmounts();
        sqrtPriceBreaks = new uint88[](length);
        sqrtPriceBreaks[params.addSpec.numberOfPriceBreaksPerSide] = input.newSqrtPrice.toUint88();

        // compute slippage price
        // look through N breaks
        // compute deltas
        // convert to addParams
        //

        // left of price,
        for (uint256 k; k < params.addSpec.numberOfPriceBreaksPerSide; k++) {
            input.targetIsA = false;
            input.targetAmount = tickDeltas[params.addSpec.numberOfPriceBreaksPerSide].deltaBOut;

            // price / (factor + 1), price / (factor * (n-1) / n + 1), price / (factor * (n-2)/n + 1)...
            uint256 factor = Math.mulDivFloor(
                params.addSpec.slippageFactorD18,
                params.addSpec.numberOfPriceBreaksPerSide - k,
                params.addSpec.numberOfPriceBreaksPerSide
            );
            sqrtPriceBreaks[k] = Math.divCeil(startingPrice, factor + ONE).toUint88();

            input.newSqrtPrice = sqrtPriceBreaks[k];

            (addParams[k], tickDeltas[k], success) = lpBalanceForArrayOfTargetAmounts(input, params.pool, params.kind);
            if (!success) sqrtPriceBreaks[k] = 0;
        }

        // right of price
        for (uint256 k; k < params.addSpec.numberOfPriceBreaksPerSide; k++) {
            uint256 index = params.addSpec.numberOfPriceBreaksPerSide + k + 1;
            input.targetIsA = true;
            input.targetAmount = tickDeltas[params.addSpec.numberOfPriceBreaksPerSide].deltaAOut;

            // price * (factor * (1 / n) + 1), price * (factor * (2 / n) + 1), price / (factor * (3 / n) + 1)...
            uint256 factor = Math.mulDivFloor(
                params.addSpec.slippageFactorD18,
                k + 1,
                params.addSpec.numberOfPriceBreaksPerSide
            );
            sqrtPriceBreaks[index] = Math.mulCeil(startingPrice, factor + ONE).toUint88();

            input.newSqrtPrice = sqrtPriceBreaks[index];

            (addParams[index], tickDeltas[index], success) = lpBalanceForArrayOfTargetAmounts(
                input,
                params.pool,
                params.kind
            );
            if (!success) {
                sqrtPriceBreaks[index - 1] = type(uint88).max;
                break;
            }
        }
        packedArgs = PackLib.packAddLiquidityArgsArray(addParams);
        packedSqrtPriceBreaks = PackLib.packArray(sqrtPriceBreaks);
    }

    function deltaReservesFromDeltaLiquidity(
        uint256 poolTickSpacing,
        uint256 tokenAScale,
        uint256 tokenBScale,
        int32 tick,
        uint128 deltaLiquidity,
        uint256 tickSqrtPrice
    ) internal pure returns (uint256 deltaA, uint256 deltaB) {
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(poolTickSpacing, tick);
        {
            uint256 lowerEdge = Math.max(sqrtLowerTickPrice, tickSqrtPrice);

            deltaB = Math.mulDivCeil(
                deltaLiquidity,
                ONE * Math.clip(sqrtUpperTickPrice, lowerEdge),
                sqrtUpperTickPrice * lowerEdge
            );
        }

        if (tickSqrtPrice < sqrtLowerTickPrice) {
            deltaA = 0;
        } else if (tickSqrtPrice >= sqrtUpperTickPrice) {
            deltaA = Math.mulCeil(deltaLiquidity, sqrtUpperTickPrice - sqrtLowerTickPrice);
            deltaB = 0;
        } else {
            deltaA = Math.mulCeil(
                deltaLiquidity,
                Math.clip(Math.min(sqrtUpperTickPrice, tickSqrtPrice), sqrtLowerTickPrice)
            );
        }
        deltaA = Math.ammScaleToTokenScale(deltaA, tokenAScale, true);
        deltaB = Math.ammScaleToTokenScale(deltaB, tokenBScale, true);
    }

    function deltasFromBinLiquidityAmounts(
        uint256 poolTickSpacing,
        uint256 tokenAScale,
        uint256 tokenBScale,
        int32[] memory ticks,
        uint128[] memory liquidityAmounts,
        uint256 newSqrtPrice
    ) internal pure returns (uint256 deltaA, uint256 deltaB, uint256[] memory deltaAs, uint256[] memory deltaBs) {
        uint256 length = ticks.length;
        deltaAs = new uint256[](length);
        deltaBs = new uint256[](length);
        for (uint256 k = 0; k < length; k++) {
            (deltaAs[k], deltaBs[k]) = deltaReservesFromDeltaLiquidity(
                poolTickSpacing,
                tokenAScale,
                tokenBScale,
                ticks[k],
                liquidityAmounts[k],
                newSqrtPrice
            );
            deltaA += deltaAs[k];
            deltaB += deltaBs[k];
        }
    }

    struct StateInfo {
        uint256 reserveA;
        uint256 reserveB;
        uint256 binTotalSupply;
        int32 activeTick;
    }

    struct RelativeLiquidityInput {
        uint256 poolTickSpacing;
        uint256 tokenAScale;
        uint256 tokenBScale;
        int32[] ticks;
        uint128[] relativeLiquidityAmounts;
        uint256 targetAmount;
        bool targetIsA;
        uint256 newSqrtPrice;
    }

    function _deltasFromRelativeBinLiquidityAmountsAndTargetAmount(
        RelativeLiquidityInput memory input
    ) internal pure returns (IMaverickV2PoolLens.TickDeltas memory output, bool success) {
        uint256 deltaA;
        uint256 deltaB;
        success = true;

        (deltaA, deltaB, output.deltaAs, output.deltaBs) = deltasFromBinLiquidityAmounts(
            input.poolTickSpacing,
            input.tokenAScale,
            input.tokenBScale,
            input.ticks,
            input.relativeLiquidityAmounts,
            input.newSqrtPrice
        );
        uint256 deltaDenominator = input.targetIsA ? deltaA : deltaB;

        if ((input.targetIsA && deltaA == 0) || (!input.targetIsA && deltaB == 0)) return (output, false);

        for (uint256 k; k < input.ticks.length; k++) {
            output.deltaAs[k] = Math
                .mulDivFloor(Math.clip(output.deltaAs[k], 1), input.targetAmount, deltaDenominator)
                .toUint128();
            output.deltaBs[k] = Math
                .mulDivFloor(Math.clip(output.deltaBs[k], 1), input.targetAmount, deltaDenominator)
                .toUint128();
            if (output.deltaAs[k] < MIN_DELTA_RESERVES && output.deltaBs[k] < MIN_DELTA_RESERVES)
                return (output, false);

            output.deltaAOut += output.deltaAs[k];
            output.deltaBOut += output.deltaBs[k];
        }
    }

    function lpBalanceForArrayOfTargetAmountsEmptyPool(
        IMaverickV2PoolLens.TickDeltas memory tickDeltas,
        RelativeLiquidityInput memory input,
        StateInfo memory existingState,
        uint8 kind
    ) internal pure returns (IMaverickV2Pool.AddLiquidityParams memory addParams) {
        addParams.ticks = input.ticks;
        addParams.kind = kind;
        addParams.amounts = new uint128[](input.ticks.length);
        for (uint256 k; k < input.ticks.length; k++) {
            bool tickIsActive = existingState.activeTick == input.ticks[k];
            addParams.amounts[k] = lpBalanceRequiredForTargetReserveAmountsOneBinTick(
                input,
                input.ticks[k],
                Math.tokenScaleToAmmScale(tickDeltas.deltaAs[k], input.tokenAScale),
                Math.tokenScaleToAmmScale(tickDeltas.deltaBs[k], input.tokenBScale),
                tickIsActive ? existingState.reserveA : 0,
                tickIsActive ? existingState.reserveB : 0,
                tickIsActive ? existingState.binTotalSupply : 0,
                input.ticks[k] < existingState.activeTick
            ).toUint128();
        }
    }

    function lpBalanceForArrayOfTargetAmounts(
        RelativeLiquidityInput memory input,
        IMaverickV2Pool pool,
        uint8 kind
    )
        internal
        view
        returns (
            IMaverickV2Pool.AddLiquidityParams memory addParams,
            IMaverickV2PoolLens.TickDeltas memory tickDeltas,
            bool success
        )
    {
        (tickDeltas, success) = _deltasFromRelativeBinLiquidityAmountsAndTargetAmount(input);
        addParams.ticks = input.ticks;
        addParams.kind = kind;

        addParams.amounts = new uint128[](input.ticks.length);
        for (uint256 k; k < input.ticks.length; k++) {
            addParams.amounts[k] = lpBalanceRequiredForTargetReserveAmountsMultiBinTick(
                input,
                pool,
                input.ticks[k],
                kind,
                Math.tokenScaleToAmmScale(tickDeltas.deltaAs[k], input.tokenAScale),
                Math.tokenScaleToAmmScale(tickDeltas.deltaBs[k], input.tokenBScale)
            ).toUint128();
        }
    }

    function donateAndSwapData(
        uint256 poolTickSpacing,
        int32 poolTick,
        uint256 poolFee,
        IERC20 tokenB,
        uint256 targetAmountB,
        uint256 targetSqrtPrice
    ) internal view returns (uint128 deltaLpBalanceB, uint256 swapAmount) {
        uint256 tokenBScale = Math.scale(IERC20Metadata(address(tokenB)).decimals());

        targetAmountB = Math.tokenScaleToAmmScale(targetAmountB, tokenBScale);
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(poolTickSpacing, poolTick);

        deltaLpBalanceB = Math.mulFloor(targetAmountB, sqrtUpperTickPrice).toUint128();

        uint256 liquidity = TickMath.getTickL(0, targetAmountB, sqrtLowerTickPrice, sqrtUpperTickPrice);
        if (targetSqrtPrice <= sqrtLowerTickPrice || targetSqrtPrice >= sqrtUpperTickPrice)
            revert LiquidityUtilitiesTargetPriceOutOfBounds(targetSqrtPrice, sqrtLowerTickPrice, sqrtUpperTickPrice);

        swapAmount = Math.mulDivCeil(
            liquidity,
            ONE * (targetSqrtPrice - sqrtLowerTickPrice),
            targetSqrtPrice * sqrtLowerTickPrice
        );
        swapAmount = Math.ammScaleToTokenScale(swapAmount, tokenBScale, true);
        swapAmount = Math.mulCeil(swapAmount, ONE - poolFee);
    }

    function getCreatePoolParams(
        IMaverickV2PoolLens.CreateAndAddParamsViewInputs memory params,
        uint256 protocolFeeRatio
    ) internal view returns (IMaverickV2PoolLens.CreateAndAddParamsInputs memory output) {
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(
            params.tickSpacing,
            params.activeTick
        );
        RelativeLiquidityInput memory input;
        StateInfo memory existingState;

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
            (output.donateParams.amounts[0], output.swapAmount) = donateAndSwapData(
                params.tickSpacing,
                params.activeTick,
                params.feeAIn,
                params.tokenB,
                params.initialTargetB,
                params.sqrtPrice
            );

            if (output.donateParams.amounts[0] < MINIMUM_LIQUIDITY)
                revert LiquidityUtilitiesInitialTargetBTooSmall(
                    params.initialTargetB,
                    output.donateParams.amounts[0],
                    MINIMUM_LIQUIDITY
                );
            existingState.binTotalSupply = output.donateParams.amounts[0];

            existingState.reserveB = Math.tokenScaleToAmmScale(
                params.initialTargetB - output.swapAmount,
                input.tokenBScale
            );
            existingState.reserveA = emulateExactOut(
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
            (
                IMaverickV2PoolLens.TickDeltas memory tickDeltas,
                bool success
            ) = _deltasFromRelativeBinLiquidityAmountsAndTargetAmount(input);
            if (!success) revert LiquidityUtilitiesFailedToFindDeltaAmounts();

            output.addParams = lpBalanceForArrayOfTargetAmountsEmptyPool(tickDeltas, input, existingState, params.kind);
            output.packedAddParams = PackLib.packAddLiquidityArgsToArray(output.addParams);
            output.deltaAOut = tickDeltas.deltaAOut;
            output.deltaBOut = tickDeltas.deltaBOut;
            output.preAddReserveA = existingState.reserveA;
            output.preAddReserveB = existingState.reserveB;
        }
    }

    function emulateExactOut(
        uint256 amountOut,
        uint256 currentReserveB,
        uint256 sqrtLowerTickPrice,
        uint256 sqrtUpperTickPrice,
        uint256 fee,
        uint256 protocolFee
    ) internal pure returns (uint256 amountAIn) {
        uint256 existingLiquidity = TickMath.getTickL(0, currentReserveB, sqrtLowerTickPrice, sqrtUpperTickPrice);

        if (existingLiquidity == 0) revert LiquidityUtilitiesNoSwapLiquidity();

        uint256 binAmountIn = Math.mulDivCeil(
            amountOut,
            sqrtLowerTickPrice,
            Math.invFloor(sqrtLowerTickPrice) - Math.divCeil(amountOut, existingLiquidity)
        );

        // some of the input is fee
        uint256 feeBasis = Math.mulDivCeil(binAmountIn, fee, ONE - fee);
        // fee is added to input amount and just increases bin liquidity
        // out = in / (1-fee)  -> out - fee * out = in  -> out = in + fee * out
        uint256 inWithoutProtocolFee = binAmountIn + feeBasis;
        // add on protocol fee
        amountAIn = protocolFee != 0
            ? Math.clip(inWithoutProtocolFee, Math.mulCeil(feeBasis, protocolFee))
            : inWithoutProtocolFee;
    }

    /**
     * @notice Calculates deltaA = liquidity * (sqrt(upper) - sqrt(lower))
     *  Calculates deltaB = liquidity / sqrt(lower) - liquidity / sqrt(upper),
     *  i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
     */
    function reservesInTickForGivenPrice(
        IMaverickV2Pool pool,
        int32 tick,
        uint256 newSqrtPrice
    ) internal view returns (IMaverickV2Pool.TickState memory tickState, bool tickLtActive, bool tickGtActive) {
        tickState = pool.getTick(tick);
        (uint256 lowerSqrtPrice, uint256 upperSqrtPrice) = TickMath.tickSqrtPrices(pool.tickSpacing(), tick);

        tickGtActive = newSqrtPrice < lowerSqrtPrice;
        tickLtActive = newSqrtPrice >= upperSqrtPrice;

        uint256 liquidity = TickMath.getTickL(tickState.reserveA, tickState.reserveB, lowerSqrtPrice, upperSqrtPrice);

        if (liquidity == 0) {
            (tickState.reserveA, tickState.reserveB) = (0, 0);
        } else {
            uint256 lowerEdge = Math.max(lowerSqrtPrice, newSqrtPrice);

            tickState.reserveA = Math
                .mulCeil(liquidity, Math.clip(Math.min(upperSqrtPrice, newSqrtPrice), lowerSqrtPrice))
                .toUint128();
            tickState.reserveB = Math
                .mulDivCeil(liquidity, ONE * Math.clip(upperSqrtPrice, lowerEdge), upperSqrtPrice * lowerEdge)
                .toUint128();
        }
    }

    function lpBalanceRequiredForTargetReserveAmountsMultiBinTick(
        RelativeLiquidityInput memory input,
        IMaverickV2Pool pool,
        int32 tick,
        uint8 kind,
        uint256 amountAMax,
        uint256 amountBMax
    ) internal view returns (uint256 deltaLpBalance) {
        (IMaverickV2Pool.TickState memory tickState, bool tickLtActive, ) = reservesInTickForGivenPrice(
            pool,
            tick,
            input.newSqrtPrice
        );
        if (tickState.reserveB != 0 || tickState.reserveA != 0) {
            uint256 liquidity;
            {
                (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(
                    input.poolTickSpacing,
                    tick
                );
                liquidity = TickMath.getTickL(
                    tickState.reserveA,
                    tickState.reserveB,
                    sqrtLowerTickPrice,
                    sqrtUpperTickPrice
                );
            }
            uint32 binId = pool.binIdByTickKind(tick, kind);
            IMaverickV2Pool.BinState memory bin = pool.getBin(binId);

            uint256 numerator = Math.max(1, uint256(tickState.totalSupply)) * Math.max(1, uint256(bin.totalSupply));
            if (tickState.reserveA != 0) {
                uint256 denominator = Math.max(1, uint256(bin.tickBalance)) * uint256(tickState.reserveA);
                amountAMax = Math.max(amountAMax, 1);
                deltaLpBalance = Math.mulDivFloor(amountAMax, numerator, denominator);
            } else {
                deltaLpBalance = type(uint256).max;
            }
            if (tickState.reserveB != 0) {
                uint256 denominator = Math.max(1, uint256(bin.tickBalance)) * uint256(tickState.reserveB);
                amountBMax = Math.max(amountBMax, 1);
                deltaLpBalance = Math.min(deltaLpBalance, Math.mulDivFloor(amountBMax, numerator, denominator));
            }
        } else {
            deltaLpBalance = emptyTickLpBalanceRequirement(input, tick, amountAMax, amountBMax, tickLtActive);
        }
    }

    function lpBalanceRequiredForTargetReserveAmountsOneBinTick(
        RelativeLiquidityInput memory input,
        int32 tick,
        uint256 amountAMax,
        uint256 amountBMax,
        uint256 reserveA,
        uint256 reserveB,
        uint256 binTotalSupply,
        bool tickLtActive
    ) internal pure returns (uint256 deltaLpBalance) {
        if (reserveB != 0 || reserveA != 0) {
            deltaLpBalance = Math.min(
                reserveA == 0 ? type(uint256).max : Math.mulDivFloor(amountAMax, binTotalSupply, reserveA),
                reserveB == 0 ? type(uint256).max : Math.mulDivFloor(amountBMax, binTotalSupply, reserveB)
            );
        } else {
            deltaLpBalance = emptyTickLpBalanceRequirement(input, tick, amountAMax, amountBMax, tickLtActive);
        }
    }

    function emptyTickLpBalanceRequirement(
        RelativeLiquidityInput memory input,
        int32 tick,
        uint256 amountAMax,
        uint256 amountBMax,
        bool tickLtActive
    ) internal pure returns (uint256 deltaLpBalance) {
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(input.poolTickSpacing, tick);
        if (tickLtActive) {
            deltaLpBalance = Math.divFloor(amountAMax, sqrtLowerTickPrice);
        } else {
            deltaLpBalance = Math.mulFloor(amountBMax, sqrtUpperTickPrice);
        }
    }

    function getBoostedPositionSpec(
        IMaverickV2BoostedPosition boostedPosition
    ) internal view returns (IMaverickV2PoolLens.BoostedPositionSpecification memory spec, int32[] memory ticks) {
        spec.pool = boostedPosition.pool();
        spec.binIds = boostedPosition.getBinIds();
        spec.ratios = boostedPosition.getRatios();
        spec.kind = boostedPosition.kind();
        ticks = boostedPosition.getTicks();
    }

    /**
     * @notice Sort ticks and amounts in addParams struct array in tick order.
     * Mutates input params array in place.
     *
     * @notice Sort operation in this function assumes that all element of the
     * input arrays have the same tick ordering.
     */
    function sortAddParamsArray(
        IMaverickV2Pool.AddLiquidityParams[] memory addParams,
        IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
    ) internal pure {
        uint256 breakPoints = addParams.length;
        uint256 length = addParams[0].ticks.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                // compare
                if (addParams[0].ticks[j] > addParams[0].ticks[j + 1]) {
                    // if there is a mis-ordering, flip values in all addParam structs
                    for (uint256 k = 0; k < breakPoints; k++) {
                        (addParams[k].ticks[j], addParams[k].ticks[j + 1]) = (
                            addParams[k].ticks[j + 1],
                            addParams[k].ticks[j]
                        );
                        (addParams[k].amounts[j], addParams[k].amounts[j + 1]) = (
                            addParams[k].amounts[j + 1],
                            addParams[k].amounts[j]
                        );
                        (tickDeltas[k].deltaAs[j], tickDeltas[k].deltaAs[j + 1]) = (
                            tickDeltas[k].deltaAs[j + 1],
                            tickDeltas[k].deltaAs[j]
                        );
                        (tickDeltas[k].deltaBs[j], tickDeltas[k].deltaBs[j + 1]) = (
                            tickDeltas[k].deltaBs[j + 1],
                            tickDeltas[k].deltaBs[j]
                        );
                    }
                }
            }
        }
    }
}
