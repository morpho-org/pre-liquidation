// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {PreLiquidation} from "./PreLiquidation.sol";
import {IPreLiquidation, PreLiquidationParams} from "./interfaces/IPreLiquidation.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IPreLiquidationFactory} from "./interfaces/IPreLiquidationFactory.sol";
import {UtilsLib} from "./libraries/periphery/UtilsLib.sol";

/// @title PreLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Factory Contract for Morpho
contract PreLiquidationFactory is IPreLiquidationFactory {
    /* IMMUTABLE */

    /// @inheritdoc IPreLiquidationFactory
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    /* EXTERNAL */

    /// @inheritdoc IPreLiquidationFactory
    function createPreLiquidation(Id id, PreLiquidationParams calldata preLiquidationParams)
        external
        returns (IPreLiquidation)
    {
        IPreLiquidation preLiquidation =
            IPreLiquidation(address(new PreLiquidation{salt: 0}(id, preLiquidationParams, address(MORPHO))));

        emit EventsLib.CreatePreLiquidation(address(preLiquidation), id, preLiquidationParams);

        return preLiquidation;
    }
}
