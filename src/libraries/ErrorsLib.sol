// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    error PreLltvTooHigh(uint256 preLltv, uint256 lltv);

    error InconsistentInput();

    error NotPreLiquidatablePosition();

    error PreLiquidationTooLarge(uint256 repaidShares, uint256 repayableShares);

    error NotMorpho();

    error ZeroAddress();

    error PreLiquidationAlreadyExists();
}
