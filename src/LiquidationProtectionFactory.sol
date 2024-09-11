// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorpho, MarketParams} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {LiquidationProtection} from "./LiquidationProtection.sol";
import {ILiquidationProtection, SubscriptionParams} from "./interfaces/ILiquidationProtection.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ILiquidationProtectionFactory} from "./interfaces/ILiquidationProtectionFactory.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Liquidation Protection Factory Contract for Morpho

contract LiquidationProtectionFactory is ILiquidationProtectionFactory {
    /* IMMUTABLE */
    IMorpho public immutable MORPHO;

    mapping(address => SubscriptionParams) subscriptions;

    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    function createPreLiquidation(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams)
        external
        returns (ILiquidationProtection liquidationProtection)
    {
        liquidationProtection = ILiquidationProtection(
            address(new LiquidationProtection(marketParams, subscriptionParams, address(MORPHO)))
        );

        emit EventsLib.CreatePreLiquidation(address(liquidationProtection), marketParams, subscriptionParams);
    }
}
