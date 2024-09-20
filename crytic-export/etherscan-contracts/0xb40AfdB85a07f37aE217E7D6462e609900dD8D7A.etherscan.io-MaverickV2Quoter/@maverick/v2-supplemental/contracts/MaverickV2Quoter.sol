// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IMaverickV2Quoter} from "./interfaces/IMaverickV2Quoter.sol";
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {PoolInspection} from "./libraries/PoolInspection.sol";
import {Path} from "./libraries/Path.sol";

/**
 * @notice Quoter contract that provides swap and addLiquidity quotes.
 * @dev The calculate functions in this contract use the pool's revert
 * functionality to compute price and therefore are not view functions.  They
 * can be called offchain using a staticcall and will operate like view
 * functions.
 */
contract MaverickV2Quoter is IMaverickV2Quoter {
    using Path for bytes;
    using Cast for uint256;

    /// @inheritdoc IMaverickV2Quoter
    function calculateAddLiquidity(
        IMaverickV2Pool pool,
        IMaverickV2Pool.AddLiquidityParams calldata params
    ) public returns (uint256 amountA, uint256 amountB, uint256 gasEstimate) {
        /* solhint-disable no-empty-blocks */
        uint256 initialGas = gasleft();
        try pool.addLiquidity(address(this), 0, params, "") {
            // ensure revert so no add occurs
            assert(false);
        } catch Error(string memory _data) {
            gasEstimate = initialGas - gasleft();
            if (bytes(_data).length == 0) {
                revert QuoterInvalidAddLiquidity();
            }
            (amountA, amountB) = abi.decode(bytes(_data), (uint256, uint256));
        }
        /* solhint-enable no-empty-blocks */
    }

    /// @inheritdoc IMaverickV2Quoter
    function calculateMultiHopSwap(
        bytes memory path,
        uint256 amount,
        bool exactOutput
    ) external returns (uint256 returnAmount, uint256 gasEstimate) {
        uint256 amountIn = amount;
        while (true) {
            bool stillMultiPoolSwap = path.hasMultiplePools();
            (IMaverickV2Pool pool, bool tokenAIn) = path.decodeFirstPool();
            int32 tickLimit = tokenAIn ? type(int32).max : type(int32).min;
            uint256 thisSwapGas;
            (amountIn, amount, thisSwapGas) = calculateSwap(
                pool,
                exactOutput ? amountIn.toUint128() : amount.toUint128(),
                tokenAIn,
                exactOutput,
                tickLimit
            );
            gasEstimate += thisSwapGas;

            if (stillMultiPoolSwap) {
                path = path.skipToken();
            } else {
                returnAmount = exactOutput ? amountIn : amount;
                break;
            }
        }
    }

    /// @inheritdoc IMaverickV2Quoter
    function calculateSwap(
        IMaverickV2Pool pool,
        uint128 amount,
        bool tokenAIn,
        bool exactOutput,
        int32 tickLimit
    ) public returns (uint256 amountIn, uint256 amountOut, uint256 gasEstimate) {
        /* solhint-disable no-empty-blocks */
        uint256 initialGas = gasleft();
        try pool.swap(address(this), IMaverickV2Pool.SwapParams(amount, tokenAIn, exactOutput, tickLimit), hex"00") {
            // ensure revert so no swap occurs
            assert(false);
        } catch Error(string memory _data) {
            gasEstimate = initialGas - gasleft();
            if (bytes(_data).length == 0) {
                revert QuoterInvalidSwap();
            }
            (amountIn, amountOut) = abi.decode(bytes(_data), (uint256, uint256));
        }
        /* solhint-enable no-empty-blocks */
    }

    /// @inheritdoc IMaverickV2Quoter
    function poolSqrtPrice(IMaverickV2Pool pool) public view returns (uint256 sqrtPrice) {
        return PoolInspection.poolSqrtPrice(pool);
    }

    function maverickV2AddLiquidityCallback(
        IERC20,
        IERC20,
        uint256 amountA,
        uint256 amountB,
        bytes calldata
    ) external pure {
        revert(string(abi.encode(amountA, amountB)));
    }

    function maverickV2SwapCallback(IERC20, uint256 amountIn, uint256 amountOut, bytes calldata) external pure {
        revert(string(abi.encode(amountIn, amountOut)));
    }
}
