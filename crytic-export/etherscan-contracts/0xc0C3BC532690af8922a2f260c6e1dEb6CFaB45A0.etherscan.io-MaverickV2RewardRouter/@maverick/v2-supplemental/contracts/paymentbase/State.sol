// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {IWETH9} from "./IWETH9.sol";
import {IState} from "./IState.sol";

abstract contract State is IState {
    IWETH9 private immutable _weth;
    IMaverickV2Factory private immutable _factory;

    constructor(IMaverickV2Factory __factory, IWETH9 __weth) {
        _factory = __factory;
        _weth = __weth;
    }

    function weth() public view returns (IWETH9 weth_) {
        weth_ = _weth;
    }

    function factory() public view returns (IMaverickV2Factory factory_) {
        factory_ = _factory;
    }
}
