// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as MORPHO;

methods {
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
}

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool =
    (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

// Check that preliquidate reverts when its inputs are not validated.
rule preLiquidateInputValidation(env e, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data) {
    preLiquidate@withrevert(e, borrower, seizedAssets, repaidShares, data);
    assert !exactlyOneZero(seizedAssets, repaidShares) => lastReverted;
}


// Checks that onMorphoRepay is only triggered by Morpho
rule onMorphoRepaySenderValidation(env e, uint256 repaidAssets, bytes data) {
    onMorphoRepay@withrevert(e, repaidAssets, data);
    assert e.msg.sender != currentContract.MORPHO => lastReverted;
}

function lastUpdateIsNotNil(PreLiquidation.Id id) returns bool {
    mathint lastUpdate;
    (_,_,_,_,lastUpdate,_) = MORPHO.market(id);
    return lastUpdate != 0;
}

invariant marketExists()
    lastUpdateIsNotNil(currentContract.ID);


invariant preLltvLTlltv()
    currentContract.PRE_LLTV < currentContract.LLTV;
