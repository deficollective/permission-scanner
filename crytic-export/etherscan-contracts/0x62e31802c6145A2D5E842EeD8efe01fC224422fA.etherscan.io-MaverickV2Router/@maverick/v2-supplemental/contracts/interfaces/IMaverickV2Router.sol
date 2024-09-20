// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ICallbackOperations} from "../routerbase/ICallbackOperations.sol";
import {IPushOperations} from "../routerbase/IPushOperations.sol";
import {IPayment} from "../paymentbase/IPayment.sol";
import {IChecks} from "../base/IChecks.sol";

/* solhint-disable no-empty-blocks */
interface IMaverickV2Router is IPayment, IChecks, ICallbackOperations, IPushOperations {}
