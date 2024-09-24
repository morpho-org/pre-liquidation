// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {
    PreLiquidation,
    Id,
    Market,
    Position,
    PreLiquidationParams,
    IMorphoRepayCallback
} from "../../src/PreLiquidation.sol";

contract PreLiquidationHarness is PreLiquidation {
    constructor(Id id, PreLiquidationParams memory _preLiquidationParams, address morpho)
        PreLiquidation(id, _preLiquidationParams, morpho)
    {}

    function _isPreLiquidatable_(uint256 collateralPrice, Position memory position, Market memory market)
        external
        view
        returns (bool)
    {
        return _isPreLiquidatable(collateralPrice, position, market);
    }
}
