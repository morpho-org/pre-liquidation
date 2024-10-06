// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    /* SOFT-LIQUIDATION ERRORS */

    error SoftLltvTooHigh();

    error SoftLCFDecreasing();

    error SoftLIFTooLow();

    error SoftLIFDecreasing();

    error InconsistentInput();

    error NotSoftLiquidatablePosition();

    error SoftLiquidationTooLarge(uint256 repaidShares, uint256 repayableShares);

    error NotMorpho();

    error NonexistentMarket();

    /* SOFT-LIQUIDATION FACTORY ERRORS */

    error ZeroAddress();
}
