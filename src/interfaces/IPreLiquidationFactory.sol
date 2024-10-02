// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IPreLiquidation} from "./IPreLiquidation.sol";
import {PreLiquidationFactory} from "../PreLiquidationFactory.sol";

interface IPreLiquidationFactory {
    function MORPHO() external view returns (IMorpho);

    function isPreLiquidation(address) external returns (bool);

    function createPreLiquidation(
        Id id,
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) external returns (IPreLiquidation preLiquidation);
}
