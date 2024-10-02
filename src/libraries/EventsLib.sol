// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @dev This event is emitted after calling `onPreLiquidate` which can tamper with the order of events.
    event PreLiquidate(
        Id indexed id,
        address indexed liquidator,
        address indexed borrower,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets
    );

    event CreatePreLiquidation(
        address indexed preLiquidation,
        Id id,
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    );
}
