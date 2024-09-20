// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

// Adapted from https://github.com/GNSPS/solidity-bytes-utils/blob/1dff13ef21304eb3634cb9e7f86c119cf280bd35/contracts/BytesLib.sol
library BytesLib {
    error BytesLibToBoolOutOfBounds();
    error BytesLibToAddressOutOfBounds();
    error BytesLibSliceOverflow();
    error BytesLibSliceOutOfBounds();
    error BytesLibInvalidLength(uint256 inputLength, uint256 expectedLength);

    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory) {
        // 31 is added to _length in assembly; need to check here that that
        // operation will not overflow
        if (_length > type(uint256).max - 31) revert BytesLibSliceOverflow();
        if (_bytes.length < _start + _length) revert BytesLibSliceOutOfBounds();

        bytes memory tempBytes;

        assembly ("memory-safe") {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address addr) {
        unchecked {
            if (_bytes.length < _start + 20) revert BytesLibToAddressOutOfBounds();

            assembly ("memory-safe") {
                addr := and(0xffffffffffffffffffffffffffffffffffffffff, mload(add(add(_bytes, 20), _start)))
            }
        }
    }

    function toBool(bytes memory _bytes, uint256 _start) internal pure returns (bool) {
        unchecked {
            if (_bytes.length < _start + 1) revert BytesLibToBoolOutOfBounds();
            uint8 tempUint;

            assembly ("memory-safe") {
                tempUint := mload(add(add(_bytes, 1), _start))
            }

            return tempUint == 1;
        }
    }

    function toAddressAddressBoolUint128Uint128(
        bytes memory _bytes
    ) internal pure returns (address addr1, address addr2, bool bool_, uint128 amount1, uint128 amount2) {
        if (_bytes.length != 73) revert BytesLibInvalidLength(_bytes.length, 73);
        uint8 temp;
        assembly ("memory-safe") {
            addr1 := and(0xffffffffffffffffffffffffffffffffffffffff, mload(add(_bytes, 20)))
            addr2 := and(0xffffffffffffffffffffffffffffffffffffffff, mload(add(_bytes, 40)))
            temp := mload(add(_bytes, 41))
            amount1 := and(0xffffffffffffffffffffffffffffffff, mload(add(_bytes, 57)))
            amount2 := and(0xffffffffffffffffffffffffffffffff, mload(add(_bytes, 73)))
        }
        bool_ = temp == 1;
    }
}
