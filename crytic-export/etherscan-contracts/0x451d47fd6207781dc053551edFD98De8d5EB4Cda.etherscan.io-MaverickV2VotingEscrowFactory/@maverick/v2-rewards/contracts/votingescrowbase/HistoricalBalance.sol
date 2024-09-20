// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

import {IHistoricalBalance} from "./IHistoricalBalance.sol";

/**
 * @notice Adds support for tracking historical balance on ERC20Votes (not just
 * historical voting power) and adds support for contributing and retrieving
 * incentives pro-rata of historical balanceOf.
 *
 * @notice Uses a timestamp-based clock for checkpoints as opposed to the
 * default OZ implementation that is blocknumber based.
 */
abstract contract HistoricalBalance is ERC20Votes, IHistoricalBalance {
    using Checkpoints for Checkpoints.Trace208;

    mapping(address account => Checkpoints.Trace208) private _balanceOfCheckpoints;

    //////////////////////
    // Past Balance
    //////////////////////

    /// @inheritdoc IHistoricalBalance
    function getPastBalanceOf(address account, uint256 timepoint) public view returns (uint256 balance) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        // cast is safe because of conditional above
        return _balanceOfCheckpoints[account].upperLookupRecent(uint48(timepoint));
    }

    //////////////////////
    // Overrides
    //////////////////////

    function _update(address from, address to, uint256 amount) internal virtual override {
        ERC20Votes._update(from, to, amount);

        if (from != to && amount > 0) {
            if (from != address(0)) {
                __push(_balanceOfCheckpoints[from], __subtract, SafeCast.toUint208(amount));
            }
            if (to != address(0)) {
                __push(_balanceOfCheckpoints[to], __add, SafeCast.toUint208(amount));
            }
        }
    }

    function clock() public view override returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @dev Machine-readable description of the clock as specified in ERC-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    //////////////////////
    // Helpers
    //////////////////////

    function __push(
        Checkpoints.Trace208 storage store,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    ) private returns (uint208, uint208) {
        return store.push(clock(), op(store.latest(), delta));
    }

    function __add(uint208 a, uint208 b) private pure returns (uint208) {
        return a + b;
    }

    function __subtract(uint208 a, uint208 b) private pure returns (uint208) {
        return a - b;
    }
}
