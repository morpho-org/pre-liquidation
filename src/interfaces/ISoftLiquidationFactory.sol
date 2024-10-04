// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ISoftLiquidation, SoftLiquidationParams} from "./ISoftLiquidation.sol";

interface ISoftLiquidationFactory {
    function MORPHO() external view returns (IMorpho);

    function isSoftLiquidation(address) external returns (bool);

    function createSoftLiquidation(Id id, SoftLiquidationParams calldata softLiquidationParams)
        external
        returns (ISoftLiquidation softLiquidation);
}
