// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

import {MaverickV2BoostedPositionDynamic} from "../MaverickV2BoostedPositionDynamic.sol";
import {IMaverickV2BoostedPosition} from "../interfaces/IMaverickV2BoostedPosition.sol";

library BoostedPositionDeployerDynamic {
    function deploy(
        string memory name,
        string memory symbol,
        IMaverickV2Pool pool,
        uint8 kind,
        uint32 binId,
        uint256 tokenAScale,
        uint256 tokenBScale
    ) external returns (IMaverickV2BoostedPosition boostedPosition) {
        boostedPosition = new MaverickV2BoostedPositionDynamic{salt: ""}(
            name,
            symbol,
            pool,
            kind,
            binId,
            tokenAScale,
            tokenBScale
        );
    }
}
