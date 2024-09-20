// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;
import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {BytesLib} from "./BytesLib.sol";

/**
 * @notice Path is [pool_addr, tokenAIn, pool_addr, tokenAIn ...], alternating 20
 * bytes and then one byte for the tokenAIn bool.
 */
library Path {
    using BytesLib for bytes;

    /**
     * @notice The length of the bytes encoded address.
     */
    uint256 private constant ADDR_SIZE = 20;

    /**
     * @notice The length of the bytes encoded bool.
     */
    uint256 private constant BOOL_SIZE = 1;

    /**
     * @notice The offset of a single token address and pool address.
     */
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + BOOL_SIZE;

    /**
     * @notice Returns true iff the path contains two or more pools.
     * @param path The encoded swap path.
     * @return True if path contains two or more pools, otherwise false.
     */
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length > NEXT_OFFSET;
    }

    /**
     * @notice Decodes the first pool in path.
     * @param path The bytes encoded swap path.
     */
    function decodeFirstPool(bytes memory path) internal pure returns (IMaverickV2Pool pool, bool tokenAIn) {
        pool = IMaverickV2Pool(path.toAddress(0));
        tokenAIn = path.toBool(ADDR_SIZE);
    }

    function decodeNextPoolAddress(bytes memory path) internal pure returns (address pool) {
        pool = path.toAddress(NEXT_OFFSET);
    }

    /**
     * @notice Skips a token + pool element from the buffer and returns the
     * remainder.
     * @param path The swap path.
     * @return The remaining token + pool elements in the path.
     */
    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }
}
