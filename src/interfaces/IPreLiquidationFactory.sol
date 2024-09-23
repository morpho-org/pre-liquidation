// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IPreLiquidation, PreLiquidationParams} from "./IPreLiquidation.sol";

/// @title IPreLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of PreLiquidation's factory.
interface IPreLiquidationFactory {
    /// @notice The address of the Morpho contract.
    function MORPHO() external view returns (IMorpho);

    /// @notice The contract address created for a specific preLiquidationId.
    function preLiquidations(bytes32) external view returns (IPreLiquidation);

    /// @notice Creates a PreLiquidation contract.
    /// @param id The Morpho market for PreLiquidations.
    /// @param preLiquidationParams The PreLiquidation params for the PreLiquidation contract.
    function createPreLiquidation(Id id, PreLiquidationParams calldata preLiquidationParams)
        external
        returns (IPreLiquidation preLiquidation);
}
