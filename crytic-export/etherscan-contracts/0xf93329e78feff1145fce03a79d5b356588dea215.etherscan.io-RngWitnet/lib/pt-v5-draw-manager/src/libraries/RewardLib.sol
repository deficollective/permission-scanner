// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UD2x18 } from "prb-math/UD2x18.sol";
import { UD60x18, convert } from "prb-math/UD60x18.sol";

/// @notice Stores the results of an auction.
/// @param recipient The recipient of the auction awards
/// @param rewardFraction The fraction of the available rewards to be sent to the recipient
struct Allocation {
  address recipient;
  UD2x18 rewardFraction;
}

/// @title RewardLib
/// @author G9 Software Inc.
/// @notice Library for calculating auction rewards.
/// @dev This library uses a parabolic fractional dutch auction (PFDA) to calculate rewards. For more details see https://dev.pooltogether.com/protocol/next/design/draw-auction#parabolic-fractional-dutch-auction-pfda
library RewardLib {
  /* ============ Internal Functions ============ */

  /**
   * @notice Calculates the fractional reward using a Parabolic Fractional Dutch Auction (PFDA)
   * given the elapsed time, auction time, and target sale parameters.
   * @param _elapsedTime The elapsed time since the start of the auction in seconds
   * @param _auctionDuration The auction duration in seconds
   * @param _targetTimeFraction The target sale time as a fraction of the total auction duration (0.0,1.0]
   * @param _targetRewardFraction The target fractional sale price
   * @return The reward fraction as a UD2x18 fraction
   */
  function fractionalReward(
    uint48 _elapsedTime,
    uint48 _auctionDuration,
    UD2x18 _targetTimeFraction,
    UD2x18 _targetRewardFraction
  ) internal pure returns (UD2x18) {
    UD60x18 x = convert(_elapsedTime).div(convert(_auctionDuration));
    UD60x18 t = UD60x18.wrap(_targetTimeFraction.unwrap());
    UD60x18 r = UD60x18.wrap(_targetRewardFraction.unwrap());
    UD60x18 rewardFraction;
    if (x.gt(t)) {
      UD60x18 tDelta = x.sub(t);
      UD60x18 oneMinusT = convert(1).sub(t);
      rewardFraction = r.add(
        convert(1).sub(r).mul(tDelta).mul(tDelta).div(oneMinusT).div(oneMinusT)
      );
    } else {
      UD60x18 tDelta = t.sub(x);
      rewardFraction = r.sub(r.mul(tDelta).mul(tDelta).div(t).div(t));
    }
    return rewardFraction.intoUD2x18();
  }

  /**
   * @notice Calculates rewards to distribute given the available reserve and completed
   * auction results.
   * @dev Each auction takes a fraction of the remaining reserve. This means that if the
   * reserve is equal to 100 and the first auction takes 50% and the second takes 50%, then
   * the first reward will be equal to 50 while the second will be 25.
   * @param _allocations Auction results to get rewards for
   * @param _reserve Reserve available for the rewards
   * @return Rewards in the same order as the auction results they correspond to
   */
  function rewards(
    Allocation[] memory _allocations,
    uint256 _reserve
  ) internal pure returns (uint256[] memory) {
    uint256 remainingReserve = _reserve;
    uint256 _allocationsLength = _allocations.length;
    uint256[] memory _rewards = new uint256[](_allocationsLength);
    for (uint256 i; i < _allocationsLength; i++) {
      _rewards[i] = reward(_allocations[i].rewardFraction, remainingReserve);
      remainingReserve = remainingReserve - _rewards[i];
    }
    return _rewards;
  }

  /**
   * @notice Calculates the reward for the given auction result and available reserve.
   * @dev If the auction reward recipient is the zero address, no reward will be given.
   * @param _rewardFraction Reward fraction to get reward for
   * @param _reserve Reserve available for the reward
   * @return Reward amount
   */
  function reward(
    UD2x18 _rewardFraction,
    uint256 _reserve
  ) internal pure returns (uint256) {
    return convert(_rewardFraction.intoUD60x18().mul(convert(_reserve)));
  }
}
