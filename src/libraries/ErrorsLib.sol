// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    error LowPreLltvError(uint256, uint256);

    error NonValidSubscription(bytes32);

    error InconsistentInput(uint256, uint256);

    error HealthyPosition();

    error CloseFactorError(uint256, uint256);

    error NotMorpho(address);
}
