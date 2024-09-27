// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as MORPHO;
using OracleMock as PRE_LIQUIDATION_ORACLE;

methods {
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
      returns (uint256, uint128, uint128) envfree;
    function PRE_LIQUIDATION_ORACLE.price() external
      returns (uint256) envfree => ALWAYS(1);
}

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool =
  (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

function summaryMulDivUp(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d-1)) / d);
}

function summaryMulDivDown(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y)/d);
}

definition tAU(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256 =
    summaryMulDivUp(shares, require_uint256(totalAssets + (10^6)), require_uint256(totalShares + (10^6)));


definition wMD(uint256 x,uint256 y) returns uint256 =
    summaryMulDivDown(x, y, require_uint256(10^18));

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


rule nonLiquidatablePositionReverts(env e,address borrower, uint256 seizedAssets, bytes data) {

    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    uint256 pBorrowShares;
    uint256 pCollateral;

    (_, _, mTotalBorrowAssets,mTotalBorrowShares,mLastUpdate, _) = MORPHO.market(currentContract.ID);
    require mLastUpdate == e.block.timestamp;

    uint256 collateralPrice = 1;

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint borrowed = require_uint256(tAU(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint borrowThreshold = require_uint256(wMD(summaryMulDivDown(pCollateral,collateralPrice,(10^36)),currentContract.PRE_LLTV));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    assert (borrowed <= borrowThreshold) => lastReverted;
}
