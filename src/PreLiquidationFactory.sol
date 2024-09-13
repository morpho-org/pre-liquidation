// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorpho, MarketParams} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {PreLiquidation} from "./PreLiquidation.sol";
import {IPreLiquidation, SubscriptionParams} from "./interfaces/IPreLiquidation.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IPreLiquidationFactory} from "./interfaces/IPreLiquidationFactory.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Factory Contract for Morpho

contract PreLiquidationFactory is IPreLiquidationFactory {
    /* IMMUTABLE */
    IMorpho public immutable MORPHO;

    mapping(bytes32 => IPreLiquidation) public subscriptions;

    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    function createPreLiquidation(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams)
        external
        returns (IPreLiquidation preLiquidation)
    {
        bytes32 preLiquidationId = getPreLiquidationId(marketParams, subscriptionParams);
        require(address(subscriptions[preLiquidationId]) == address(0), ErrorsLib.RedundantMarket());

        preLiquidation = IPreLiquidation(address(new PreLiquidation(marketParams, subscriptionParams, address(MORPHO))));
        subscriptions[preLiquidationId] = preLiquidation;

        emit EventsLib.CreatePreLiquidation(address(preLiquidation), marketParams, subscriptionParams);
    }

    function getPreLiquidationId(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(marketParams, subscriptionParams));
    }
}
