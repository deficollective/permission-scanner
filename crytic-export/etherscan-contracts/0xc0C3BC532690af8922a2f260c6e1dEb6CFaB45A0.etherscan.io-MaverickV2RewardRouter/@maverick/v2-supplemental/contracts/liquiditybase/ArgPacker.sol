// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {PackLib} from "../libraries/PackLib.sol";
import {IArgPacker} from "./IArgPacker.sol";

/**
 * @notice View functions that pack and unpack addLiquidity parameters.
 */
abstract contract ArgPacker is IArgPacker {
    /// @inheritdoc IArgPacker
    function unpackAddLiquidityArgs(
        bytes memory argsPacked
    ) public pure returns (IMaverickV2Pool.AddLiquidityParams memory args) {
        return PackLib.unpackAddLiquidityArgs(argsPacked);
    }

    /// @inheritdoc IArgPacker
    function packAddLiquidityArgs(
        IMaverickV2Pool.AddLiquidityParams memory args
    ) public pure returns (bytes memory argsPacked) {
        return PackLib.packAddLiquidityArgs(args);
    }

    /// @inheritdoc IArgPacker
    function packAddLiquidityArgsArray(
        IMaverickV2Pool.AddLiquidityParams[] memory args
    ) public pure returns (bytes[] memory argsPacked) {
        return PackLib.packAddLiquidityArgsArray(args);
    }

    /// @inheritdoc IArgPacker
    function unpackUint88Array(bytes memory packedArray) public pure returns (uint88[] memory fullArray) {
        fullArray = PackLib.unpackUint88Array(packedArray);
    }

    /// @inheritdoc IArgPacker
    function packUint88Array(uint88[] memory fullArray) public pure returns (bytes memory packedArray) {
        packedArray = PackLib.packArray(fullArray);
    }
}
