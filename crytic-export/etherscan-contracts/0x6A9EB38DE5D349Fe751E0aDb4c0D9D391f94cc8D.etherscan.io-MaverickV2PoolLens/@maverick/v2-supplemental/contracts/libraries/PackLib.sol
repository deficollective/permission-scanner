// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

// adapted from https://github.com/latticexyz/mud/blob/main/packages/store/src/Slice.sol
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {SafeCast as Cast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {BytesLib} from "./BytesLib.sol";

library PackLib {
    using Cast for uint256;
    using BytesLib for bytes;

    function unpackExactInputSingleArgsAmounts(
        bytes memory argsPacked
    )
        internal
        pure
        returns (address recipient, IMaverickV2Pool pool, bool tokenAIn, uint256 amountIn, uint256 amountOutMinimum)
    {
        address pool_;
        (recipient, pool_, tokenAIn, amountIn, amountOutMinimum) = argsPacked.toAddressAddressBoolUint128Uint128();
        pool = IMaverickV2Pool(pool_);
    }

    function unpackAddLiquidityArgs(
        bytes memory argsPacked
    ) internal pure returns (IMaverickV2Pool.AddLiquidityParams memory args) {
        args.kind = uint8(argsPacked[0]);
        args.ticks = unpackInt32Array(argsPacked.slice(1, argsPacked.length - 1));
        uint256 startByte = args.ticks.length * 4 + 2;
        args.amounts = unpackUint128Array(argsPacked.slice(startByte, argsPacked.length - startByte));
    }

    function packAddLiquidityArgs(
        IMaverickV2Pool.AddLiquidityParams memory args
    ) internal pure returns (bytes memory argsPacked) {
        argsPacked = abi.encodePacked(args.kind);
        argsPacked = bytes.concat(argsPacked, packArray(args.ticks));
        argsPacked = bytes.concat(argsPacked, packArray(args.amounts));
    }

    function packAddLiquidityArgsToArray(
        IMaverickV2Pool.AddLiquidityParams memory args
    ) internal pure returns (bytes[] memory argsPacked) {
        argsPacked = new bytes[](1);
        argsPacked[0] = packAddLiquidityArgs(args);
    }

    function packAddLiquidityArgsArray(
        IMaverickV2Pool.AddLiquidityParams[] memory args
    ) internal pure returns (bytes[] memory argsPacked) {
        argsPacked = new bytes[](args.length);
        for (uint256 k; k < args.length; k++) {
            argsPacked[k] = packAddLiquidityArgs(args[k]);
        }
    }

    function unpackInt32Array(bytes memory input) internal pure returns (int32[] memory array) {
        uint256[] memory output = _unpackArray(input, 4);
        assembly ("memory-safe") {
            array := output
        }
    }

    function unpackUint128Array(bytes memory input) internal pure returns (uint128[] memory array) {
        uint256[] memory output = _unpackArray(input, 16);
        assembly ("memory-safe") {
            array := output
        }
    }

    function unpackUint88Array(bytes memory input) internal pure returns (uint88[] memory array) {
        uint256[] memory output = _unpackArray(input, 11);
        assembly ("memory-safe") {
            array := output
        }
    }

    function packArray(int32[] memory array) internal pure returns (bytes memory output) {
        uint256[] memory input;
        assembly ("memory-safe") {
            input := array
        }
        output = _packArray(input, 4);
    }

    function packArray(uint128[] memory array) internal pure returns (bytes memory output) {
        uint256[] memory input;
        assembly ("memory-safe") {
            input := array
        }
        output = _packArray(input, 16);
    }

    function packArray(uint88[] memory array) internal pure returns (bytes memory output) {
        uint256[] memory input;
        assembly ("memory-safe") {
            input := array
        }
        output = _packArray(input, 11);
    }

    /*
     * @notice [length, array[0], array[1],..., array[length-1]]. length is 1 bytes.
     * @dev Unpacked signed array elements will contain "dirty bits".  That is,
     * this function does not 0xf pad signed return elements.
     */
    function _unpackArray(bytes memory input, uint256 elementBytes) internal pure returns (uint256[] memory array) {
        uint256 packedPointer;
        uint256 arrayLength;
        assembly ("memory-safe") {
            // read from input pointer + 32 bytes
            // pad 1-byte length value to fill 32 bytes (248 pad bits)
            arrayLength := shr(248, mload(add(input, 0x20)))
            packedPointer := add(input, 0x21)
        }

        uint256 padRight = 256 - 8 * elementBytes;
        assembly ("memory-safe") {
            // Allocate a word for each element, and a word for the array's length
            let allocateBytes := add(mul(arrayLength, 32), 0x20)
            // Allocate memory and update the free memory pointer
            array := mload(0x40)
            mstore(0x40, add(array, allocateBytes))

            // Store array length
            mstore(array, arrayLength)

            for {
                let i := 0
                let arrayCursor := add(array, 0x20) // skip array length
                let packedCursor := packedPointer
            } lt(i, arrayLength) {
                // Loop until we reach the end of the array
                i := add(i, 1)
                arrayCursor := add(arrayCursor, 0x20) // increment array pointer by one word
                packedCursor := add(packedCursor, elementBytes) // increment packed pointer by one element size
            } {
                mstore(arrayCursor, shr(padRight, mload(packedCursor))) // unpack one array element
            }
        }
    }

    /*
     * @dev [length, array[0], array[1],..., array[length-1]]. length is 1 bytes.
     */
    function _packArray(uint256[] memory array, uint256 elementBytes) internal pure returns (bytes memory output) {
        // cast to check size fits in 8 bits
        uint8 arrayLength = array.length.toUint8();
        uint256 packedLength = arrayLength * elementBytes + 1;

        output = new bytes(packedLength);

        uint256 padLeft = 256 - 8 * elementBytes;
        assembly ("memory-safe") {
            // Store array length
            mstore(add(output, 0x20), shl(248, arrayLength))

            for {
                let i := 0
                let arrayCursor := add(array, 0x20) // skip array length
                let packedCursor := add(output, 0x21) // skip length
            } lt(i, arrayLength) {
                // Loop until we reach the end of the array
                i := add(i, 1)
                arrayCursor := add(arrayCursor, 0x20) // increment array pointer by one word
                packedCursor := add(packedCursor, elementBytes) // increment packed pointer by one element size
            } {
                mstore(packedCursor, shl(padLeft, mload(arrayCursor))) // pack one array element
            }
        }
    }
}
