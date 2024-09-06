// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    event Liquidate(
        address indexed borrower,
        address indexed liquidator,
        Id indexed marketId,
        uint256 subscriptionNumber,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets
    );

    event Subscribe(
        address indexed borrower,
        Id indexed marketId,
        uint256 indexed subscriptionNumber,
        uint256 slltv,
        uint256 closeFactor,
        uint256 liquidationIncentive
    );

    event Unsubscribe(address indexed borrower, Id indexed marketId, uint256 indexed subscriptionNumber);
}
