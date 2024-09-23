// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {PreLiquidation, Id, MarketParams, PreLiquidationParams} from "../../src/PreLiquidation.sol";

/// @title PreLiquidationHarness
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Harness Contract to be used with the Certora prover
contract PreLiquidationHarness is PreLiquidation {
    constructor(MarketParams memory _marketParams, PreLiquidationParams memory _preLiquidationParams, address morpho)
        PreLiquidation(_marketParams, _preLiquidationParams, morpho)
    {}

    function _isPreLiquidatable_(address borrower, uint256 collateralPrice) external view returns (bool) {
        return _isPreLiquidatable(borrower, collateralPrice);
    }
}
