// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IPreLiquidation, PreLiquidationParams} from "./IPreLiquidation.sol";
import {PreLiquidationFactory} from "../PreLiquidationFactory.sol";
/// @title IPreLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of PreLiquidation's factory.
interface IPreLiquidationFactory {

    function MORPHO() external view returns (IMorpho);


    function createPreLiquidation(Id id, PreLiquidationParams calldata preLiquidationParams)
        external
        returns (IPreLiquidation preLiquidation);
}
