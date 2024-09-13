// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SubscriptionParams} from "../interfaces/IPreLiquidation.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    event PreLiquidate(
        address indexed borrower,
        Id indexed marketId,
        address indexed liquidator,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets
    );

    event SetSubscription(address indexed borrower, bool status);

    event CreatePreLiquidation(
        address indexed subscription, MarketParams marketParams, SubscriptionParams subscriptionParams
    );
}
