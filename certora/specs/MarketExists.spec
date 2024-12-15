// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as MORPHO;

methods {
    function MORPHO.lastUpdate(PreLiquidation.Id) external returns (uint256) envfree;
    // To fix an issue where immutable variables are not linked in the constructor.
    function _.market(PreLiquidation.Id) external => DISPATCHER(true);
}

persistent ghost uint256 lastTimestamp;

hook TIMESTAMP uint newTimestamp {
    // Safe require because timestamps are guaranteed to be increasing.
    require newTimestamp >= lastTimestamp;
    // Safe require as it corresponds to some time very far into the future.
    require newTimestamp < 2^63;
    lastTimestamp = newTimestamp;
}

// Ensure that the pre-liquidation contract interacts with a created market.

invariant marketExists()
    MORPHO.lastUpdate(currentContract.ID) != 0;
