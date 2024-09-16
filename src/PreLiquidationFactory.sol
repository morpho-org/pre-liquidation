// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorpho, MarketParams} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {PreLiquidation} from "./PreLiquidation.sol";
import {IPreLiquidation, PreLiquidationParams} from "./interfaces/IPreLiquidation.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IPreLiquidationFactory} from "./interfaces/IPreLiquidationFactory.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Factory Contract for Morpho
contract PreLiquidationFactory is IPreLiquidationFactory {
    /* IMMUTABLE */

    /// @inheritdoc IPreLiquidationFactory
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @inheritdoc IPreLiquidationFactory
    mapping(bytes32 => IPreLiquidation) public preLiquidations;

    /* CONSTRUCTOR */

    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    /* EXTERNAL */

    /// @inheritdoc IPreLiquidationFactory
    function createPreLiquidation(
        MarketParams calldata marketParams,
        PreLiquidationParams calldata preLiquidationParams
    ) external returns (IPreLiquidation preLiquidation) {
        bytes32 preLiquidationId = getPreLiquidationId(marketParams, preLiquidationParams);
        require(address(preLiquidations[preLiquidationId]) == address(0), ErrorsLib.RedundantMarket());

        preLiquidation =
            IPreLiquidation(address(new PreLiquidation(marketParams, preLiquidationParams, address(MORPHO))));
        preLiquidations[preLiquidationId] = preLiquidation;

        emit EventsLib.CreatePreLiquidation(address(preLiquidation), marketParams, preLiquidationParams);
    }

    /* INTERNAL */

    function getPreLiquidationId(MarketParams calldata marketParams, PreLiquidationParams calldata preLiquidationParams)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(marketParams, preLiquidationParams));
    }
}
