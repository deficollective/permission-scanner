// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IWETH9} from "./IWETH9.sol";
import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";

interface IState {
    function weth() external view returns (IWETH9 _weth);
    function factory() external view returns (IMaverickV2Factory _factory);
}
