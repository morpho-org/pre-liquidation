// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SoftLiquidationParams} from "../interfaces/ISoftLiquidation.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @dev This event is emitted after calling `onSoftLiquidate` which can tamper with the order of events.
    event SoftLiquidate(
        Id indexed id,
        address indexed liquidator,
        address indexed borrower,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets
    );

    event CreateSoftLiquidation(address indexed softLiquidation, Id id, SoftLiquidationParams softLiquidationParams);
}
