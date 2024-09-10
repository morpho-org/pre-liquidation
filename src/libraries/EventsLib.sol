// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SubscriptionParams} from "../interfaces/ILiquidationProtection.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    event Liquidate(
        address indexed borrower,
        Id indexed marketId,
        SubscriptionParams subscriptionParams,
        address indexed liquidator,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets
    );

    event Subscribe(address indexed borrower);

    event Unsubscribe(address indexed borrower);

    event CreateSubscription(
        address indexed subscription, MarketParams marketParams, SubscriptionParams subscriptionParams
    );
}
