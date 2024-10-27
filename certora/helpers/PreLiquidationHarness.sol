// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {PreLiquidation, Market, Position, Id, PreLiquidationParams} from "src/PreLiquidation.sol";

contract PreLiquidationHarness is PreLiquidation {
    constructor(address morpho, Id id, PreLiquidationParams memory _preLiquidationParams)
        PreLiquidation(morpho, id, _preLiquidationParams)
    {}

    function market_(Id id) external view returns (Market memory) {
        return MORPHO.market(id);
    }

    function position_(Id id, address borrower) external view returns (Position memory) {
        return MORPHO.position(id, borrower);
    }
}
