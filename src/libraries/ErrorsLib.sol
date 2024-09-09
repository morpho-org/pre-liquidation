// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    error PreLltvTooHigh(uint256 prelltv, uint256 lltv);

    error InvalidSubscription();

    error InconsistentInput(uint256 seizedAssets, uint256 repaidShares);

    error HealthyPosition();

    error LiquidationTooLarge(uint256 repaidShares, uint256 repayableShares);

    error NotMorpho();
}
