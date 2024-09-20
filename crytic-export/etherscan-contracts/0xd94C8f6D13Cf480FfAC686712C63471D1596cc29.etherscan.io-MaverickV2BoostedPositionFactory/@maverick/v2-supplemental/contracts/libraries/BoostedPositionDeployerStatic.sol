// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {MaverickV2BoostedPositionStatic} from "../MaverickV2BoostedPositionStatic.sol";
import {IMaverickV2BoostedPosition} from "../interfaces/IMaverickV2BoostedPosition.sol";

library BoostedPositionDeployerStatic {
    function deploy(
        string memory name,
        string memory symbol,
        IMaverickV2Pool pool,
        uint8 binCount,
        bytes32[3] memory binData,
        bytes32[12] memory ratioData
    ) external returns (IMaverickV2BoostedPosition boostedPosition) {
        boostedPosition = new MaverickV2BoostedPositionStatic{salt: ""}(
            name,
            symbol,
            pool,
            binCount,
            binData,
            ratioData
        );
    }
}
