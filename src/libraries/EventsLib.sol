// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    event Liquidate(
        uint256 indexed subscriptionNumber,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets,
        uint256 badDebtAssets,
        uint256 badDebtShares
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
