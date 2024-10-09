// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as MORPHO;

methods {
    function _.market(PreLiquidation.Id) external => DISPATCHER(true);
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function _.price() external => mockPrice() expect uint256;
}

persistent ghost uint256 lastTimestamp;

hook TIMESTAMP uint newTimestamp {
    // Safe require because timestamps are guaranteed to be increasing.
    require newTimestamp >= lastTimestamp;
    // Safe require as it corresponds to some time very far into the future.
    require newTimestamp < 2^63;
    lastTimestamp = newTimestamp;
}

function mockPrice() returns uint256 {
    uint256 price;
    return price;
}

function lastUpdateIsNotNil(PreLiquidation.Id id) returns bool {
    mathint lastUpdate;
    (_,_,_,_,lastUpdate,_) = MORPHO.market(id);
    return lastUpdate != 0;
}

//Ensure constructor requirement.

invariant marketExists()
    lastUpdateIsNotNil(currentContract.ID);
