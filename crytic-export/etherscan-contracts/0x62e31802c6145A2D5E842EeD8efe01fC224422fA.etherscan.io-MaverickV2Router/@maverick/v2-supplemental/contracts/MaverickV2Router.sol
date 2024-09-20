// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Factory} from "@maverick/v2-common/contracts/interfaces/IMaverickV2Factory.sol";

import {IMaverickV2Router} from "./interfaces/IMaverickV2Router.sol";
import {CallbackOperations} from "./routerbase/CallbackOperations.sol";
import {PushOperations} from "./routerbase/PushOperations.sol";
import {Checks} from "./base/Checks.sol";
import {State} from "./paymentbase/State.sol";
import {IWETH9} from "./paymentbase/IWETH9.sol";

/**
 * @notice Swap router functions for Maverick V2.  This contract requires that
 * users approve a spending allowance in order to pay for swaps.
 *
 * @notice The functions in this contract are partitioned into two subcontracts that
 * implement both push-based and callback-based swaps.  Maverick V2 provides
 * two mechanisms for paying for a swap:
 * - Push the input assets to the pool and then call swap.  This avoids a
 * callback to transfer the input assets and is generally more gas efficient but
 * is only suitable for exact-input swaps where the caller knows how much input
 * they need to send to the pool.
 * - Callback payment where the pool calls a callback function on this router
 * to settle up for the input amount of the swap.
 */
contract MaverickV2Router is Checks, PushOperations, CallbackOperations, IMaverickV2Router {
    constructor(IMaverickV2Factory _factory, IWETH9 _weth) State(_factory, _weth) {}
}
