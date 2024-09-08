// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing errors.
library ErrorsLib {
    error LowPreLltvError(uint256 prelltv, uint256 lltv);

    error NonValidSubscription(bytes32 subscriptionId);

    error InconsistentInput(uint256 seizedAssets, uint256 repaidShares);

    error HealthyPosition();

    error CloseFactorError(uint256 repayableShares, uint256 repaidShares);

    error NotMorpho(address caller);
}
