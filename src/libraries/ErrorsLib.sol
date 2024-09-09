// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    error PreLltvTooHigh(uint256, uint256);

    error InvalidSubscription(uint256);

    error InconsistentInput(uint256, uint256);

    error HealthyPosition();

    error LiquidationTooLarge(uint256, uint256);

    error NotMorpho();
}
