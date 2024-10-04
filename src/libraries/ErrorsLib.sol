// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    /* PRELIQUIDATION ERRORS */

    error PreLltvTooHigh();

    error PreLCFDecreasing();

    error PreLIFTooLow();

    error PreLIFDecreasing();

    error InconsistentInput();

    error NotPreLiquidatablePosition();

    error PreLiquidationTooLarge(uint256 repaidShares, uint256 repayableShares);

    error NotMorpho();

    error NonexistentMarket();

    /* PRELIQUIDATION FACTORY ERRORS */

    error ZeroAddress();
}
