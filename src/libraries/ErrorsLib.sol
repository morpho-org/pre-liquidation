// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    /* PreLiquidation errors */

    error PreLltvTooHigh();

    error InconsistentInput();

    error NotPreLiquidatablePosition();

    error PreLiquidationTooLarge(uint256 repaidShares, uint256 repayableShares);

    error NotMorpho();

    error NonexistentMarket();

    /* PreLiquidation Factory errors */

    error ZeroAddress();
}
