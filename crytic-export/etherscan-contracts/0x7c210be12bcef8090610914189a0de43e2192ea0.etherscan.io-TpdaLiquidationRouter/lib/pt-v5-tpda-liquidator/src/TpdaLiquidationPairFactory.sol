// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ILiquidationSource, TpdaLiquidationPair } from "./TpdaLiquidationPair.sol";

/// @title TpdaLiquidationPairFactory
/// @author G9 Software Inc.
/// @notice Factory contract for deploying TpdaLiquidationPair contracts.
contract TpdaLiquidationPairFactory {
    /* ============ Events ============ */

    /// @notice Emitted when a new TpdaLiquidationPair is created
    /// @param pair The address of the new pair
    /// @param source The liquidation source that the pair is using
    /// @param tokenIn The input token for the pair
    /// @param tokenOut The output token for the pair
    /// @param targetAuctionPeriod The duration of auctions
    /// @param targetAuctionPrice The minimum auction size in output tokens
    /// @param smoothingFactor The 18 decimal smoothing fraction for the liquid balance
    event PairCreated(
        TpdaLiquidationPair indexed pair,
        ILiquidationSource source,
        address indexed tokenIn,
        address indexed tokenOut,
        uint64 targetAuctionPeriod,
        uint192 targetAuctionPrice,
        uint256 smoothingFactor
    );

    /* ============ Variables ============ */

    /// @notice Tracks an array of all pairs created by this factory
    TpdaLiquidationPair[] public allPairs;

    /* ============ Mappings ============ */

    /// @notice Mapping to verify if a TpdaLiquidationPair has been deployed via this factory.
    mapping(address pair => bool wasDeployed) public deployedPairs;

    /// @notice Creates a new TpdaLiquidationPair and registers it within the factory
    /// @param _source The liquidation source that the pair will use
    /// @param _tokenIn The input token for the pair
    /// @param _tokenOut The output token for the pair
    /// @param _targetAuctionPeriod The duration of auctions
    /// @param _targetAuctionPrice The initial auction price
    /// @param _smoothingFactor The degree of smoothing to apply to the available token balance
    /// @return The new liquidation pair
    function createPair(
        ILiquidationSource _source,
        address _tokenIn,
        address _tokenOut,
        uint64 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) external returns (TpdaLiquidationPair) {
        TpdaLiquidationPair _liquidationPair = new TpdaLiquidationPair(
            _source,
            _tokenIn,
            _tokenOut,
            _targetAuctionPeriod,
            _targetAuctionPrice,
            _smoothingFactor
        );

        allPairs.push(_liquidationPair);
        deployedPairs[address(_liquidationPair)] = true;

        emit PairCreated(
            _liquidationPair,
            _source,
            _tokenIn,
            _tokenOut,
            _targetAuctionPeriod,
            _targetAuctionPrice,
            _smoothingFactor
        );

        return _liquidationPair;
    }

    /// @notice Total number of TpdaLiquidationPair deployed by this factory.
    /// @return Number of TpdaLiquidationPair deployed by this factory.
    function totalPairs() external view returns (uint256) {
        return allPairs.length;
    }
}
