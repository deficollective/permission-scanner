// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

/**
 * @notice Facilitates storing the BP binIds and ratios as immutables which
 * avoids storage operations when minting/burning BP positions.
 */
abstract contract ImmutableArrayGetter {
    uint8 private immutable _binCount;

    bytes32 private immutable binIds12345678;
    bytes32 private immutable binIds910111213141516;
    bytes32 private immutable binIds1718192021222324;
    bytes32 private immutable ratios12;
    bytes32 private immutable ratios34;
    bytes32 private immutable ratios56;
    bytes32 private immutable ratios78;
    bytes32 private immutable ratios910;
    bytes32 private immutable ratios1112;
    bytes32 private immutable ratios1314;
    bytes32 private immutable ratios1516;
    bytes32 private immutable ratios1718;
    bytes32 private immutable ratios1920;
    bytes32 private immutable ratios2122;
    bytes32 private immutable ratios2324;

    constructor(uint8 binCount_, bytes32[3] memory binIds, bytes32[12] memory ratios) {
        {
            (_binCount, ratios12, ratios34, ratios56, ratios78, ratios910) = (
                binCount_,
                ratios[0],
                ratios[1],
                ratios[2],
                ratios[3],
                ratios[4]
            );
        }
        {
            (ratios1112, ratios1314, ratios1516, ratios1718, ratios1920) = (
                ratios[5],
                ratios[6],
                ratios[7],
                ratios[8],
                ratios[9]
            );
        }
        {
            (ratios2122, ratios2324) = (ratios[10], ratios[11]);
        }
        {
            (binIds12345678, binIds910111213141516, binIds1718192021222324) = (binIds[0], binIds[1], binIds[2]);
        }
    }

    function _getBinIds() internal view returns (uint32[] memory binIds_) {
        binIds_ = new uint32[](_binCount);
        for (uint256 k; k < _binCount; k++) {
            binIds_[k] = _getBinId(k);
        }
    }

    function _getRatios() internal view returns (uint128[] memory ratios_) {
        ratios_ = new uint128[](_binCount);
        for (uint256 k; k < _binCount; k++) {
            ratios_[k] = _getRatio(k);
        }
    }

    function _getRatio(uint256 index) private view returns (uint128 value) {
        bytes32 ratioBytes = _getRatioBytes(index);
        assembly ("memory-safe") {
            if eq(mod(index, 2), 1) {
                ratioBytes := shr(128, ratioBytes)
            }
            value := and(0xffffffffffffffffffffffffffffffff, ratioBytes)
        }
    }

    function _getRatioBytes(uint256 index) private view returns (bytes32 ratiosBytes) {
        if (index < 2) return ratios12;
        if (index < 4) return ratios34;
        if (index < 6) return ratios56;
        if (index < 8) return ratios78;
        if (index < 10) return ratios910;
        if (index < 12) return ratios1112;
        if (index < 14) return ratios1314;
        if (index < 16) return ratios1516;
        if (index < 18) return ratios1718;
        if (index < 20) return ratios1920;
        if (index < 22) return ratios2122;
        if (index < 24) return ratios2324;
    }

    function _getBinId(uint256 index) internal view returns (uint32 value) {
        bytes32 binIdBytes = _getBinIdBytes(index);
        assembly ("memory-safe") {
            let modulo := mod(index, 8)
            value := and(0xffffffff, shr(mul(modulo, 32), binIdBytes))
        }
    }

    function _getBinIdBytes(uint256 index) private view returns (bytes32 binIdBytes) {
        if (index < 8) return binIds12345678;
        if (index < 16) return binIds910111213141516;
        if (index < 24) return binIds1718192021222324;
    }
}
