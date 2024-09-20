// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

interface IArgPacker {
    /**
     * @notice Packs addLiquidity paramters into a bytes object.  The packing
     * is [kind, ticksArray, amountsArray] where the arrays are packed like
     * this: [length, array[0], array[1],..., array[length-1]]. length is 1
     * byte (256 total possible elements).
     */
    function packAddLiquidityArgs(
        IMaverickV2Pool.AddLiquidityParams memory args
    ) external pure returns (bytes memory argsPacked);

    /**
     * @notice Unpacks packed addLiquidity parameters.
     */
    function unpackAddLiquidityArgs(
        bytes memory argsPacked
    ) external pure returns (IMaverickV2Pool.AddLiquidityParams memory args);

    /**
     * @notice Packs addLiquidity paramters array element-wise.
     */
    function packAddLiquidityArgsArray(
        IMaverickV2Pool.AddLiquidityParams[] memory args
    ) external pure returns (bytes[] memory argsPacked);

    /**
     * @notice Packs sqrtPrice breaks array with this format: [length,
     * array[0], array[1],..., array[length-1]] where length is 1 byte.

     */
    function packUint88Array(uint88[] memory fullArray) external pure returns (bytes memory packedArray);

    /**
     * @notice Unpacks sqrtPrice breaks bytes object into array.
     */
    function unpackUint88Array(bytes memory packedArray) external pure returns (uint88[] memory fullArray);
}
