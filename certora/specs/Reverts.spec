// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as MORPHO;

methods {
    function _.market(PreLiquidation.Id) external => DISPATCHER(true);
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
      returns (uint256, uint128, uint128) envfree;
    function MORPHO.idToMarketParams(PreLiquidation.Id) external
      returns (address, address, address, address, uint256) envfree;
    function _.price() external => mockPrice() expect uint256;
}

persistent ghost uint256 lastPrice;
persistent ghost bool priceChanged;
persistent  ghost bool preLiquidateReverted;

function mockPrice() returns uint256 {
    uint256 updatedPrice;
    if (updatedPrice != lastPrice) {
        priceChanged = true;
        lastPrice = updatedPrice;
    }
    return updatedPrice;
}

function summaryMulDivUp(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d-1)) / d);
}

function summaryMulDivDown(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y)/d);
}

definition WAD() returns uint256 = 10^18;

definition ORACLE_SCALE() returns uint256  = 10^36;

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool =
  (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

definition tAU(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256 =
    summaryMulDivUp(shares, require_uint256(totalAssets + (10^6)), require_uint256(totalShares + (10^6)));

definition tSU(uint256 assets, uint256 totalAssets, uint256 totalShares) returns uint256 =
    summaryMulDivUp(assets, require_uint256(totalShares + (10^6)), require_uint256(totalAssets + (10^6)));

definition wDU(uint256 x,uint256 y) returns uint256 = summaryMulDivUp(x, WAD(), y);

definition wDD(uint256 x,uint256 y) returns uint256 = summaryMulDivDown(x, WAD(), y);

definition wMD(uint256 x,uint256 y) returns uint256 = summaryMulDivDown(x, y, WAD());

definition computeFactor(mathint ltv, mathint lLtv, mathint preLLTV, mathint factor1, mathint factor2)
    returns mathint =
    wMD(wDD(require_uint256(ltv - preLLTV),
            require_uint256(lLtv - preLLTV)),
        require_uint256(factor2 - factor1)) + factor1;

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

//Ensure constructor requirements.

invariant marketExists()
    lastUpdateIsNotNil(currentContract.ID);

invariant preLltvLTlltv()
    currentContract.PRE_LLTV < currentContract.LLTV;

invariant preLCFIncreasing()
    currentContract.PRE_LCF_1 <= currentContract.PRE_LCF_2
    && currentContract.PRE_LCF_1 <= WAD();

invariant preLIFIncreasing()
    WAD() <= currentContract.PRE_LIF_1
    && currentContract.PRE_LIF_1 <= currentContract.PRE_LIF_2
    && currentContract.PRE_LIF_2 <= wDD(WAD(),currentContract.LLTV)
{
    preserved
        {
            requireInvariant preLltvLTlltv ();
        }
}

// Check that preLiquidate reverts when its inputs are not validated.
rule preLiquidateInputValidation(env e, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data) {
    requireInvariant preLltvLTlltv();
    requireInvariant preLCFIncreasing();
    requireInvariant preLIFIncreasing();
    preLiquidate@withrevert(e, borrower, seizedAssets, repaidShares, data);
    assert !exactlyOneZero(seizedAssets, repaidShares) => lastReverted;
}

// Check that collateralQuoted == 0 would revert by failing require-statements.
rule zeroCollateralQuotedReverts() {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    uint256 collateralPrice;

    requireInvariant preLltvLTlltv();

    uint256 collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));
    uint256 borrowed = require_uint256(tAU(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));

    uint256 higherBound = wMD(collateralQuoted, currentContract.LLTV);
    uint256 lowerBound = wMD(collateralQuoted, currentContract.PRE_LLTV);

    assert  collateralQuoted == 0 => (lowerBound >= borrowed || borrowed > higherBound);
}

// Check that a liquidatable position implies that ltv > PRE_LLTV holds.
rule preLiquidatableEquivlLtvLTPreLltv() {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    uint256 collateralPrice;

    requireInvariant preLltvLTlltv();

    uint256 collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    uint256 borrowed = require_uint256(tAU(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    uint256 ltv = require_uint256(wDU(borrowed,collateralQuoted));
    uint256 lowerBound = wMD(collateralQuoted, currentContract.PRE_LLTV);

    assert (lowerBound < borrowed) <=> ltv > currentContract.PRE_LLTV;
}

// Check that pre-liqudidating a position such that ltv <= PRE_LLTV would revert.
rule nonLiquidatablePositionReverts(env e,address borrower, uint256 seizedAssets, bytes data) {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    requireInvariant preLltvLTlltv();
    requireInvariant preLCFIncreasing();
    requireInvariant preLIFIncreasing();

    (_, _, mTotalBorrowAssets,mTotalBorrowShares,mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    // Consider that the collateral price hasn't changed.
    priceChanged = false;

    uint256 collateralPrice = mockPrice();

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    mathint borrowed = require_uint256(tAU(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint ltv = require_uint256(wDU(require_uint256(borrowed), require_uint256(collateralQuoted)));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    assert !priceChanged && (ltv <= currentContract.PRE_LLTV) => lastReverted;
}

rule excessivePreliquidationReverts(env e,address borrower, uint256 seizedAssets, bytes data) {
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    uint256 pBorrowShares;
    uint256 pCollateral;

    (_, _, mTotalBorrowAssets,mTotalBorrowShares,mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    // Consider that the collateral price hasn't changed.
    priceChanged = false;

    uint256 collateralPrice = mockPrice();

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    requireInvariant preLltvLTlltv();
    requireInvariant preLCFIncreasing();
    requireInvariant preLIFIncreasing();

    mathint borrowed = require_uint256(tAU(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint ltv = require_uint256(wDU(require_uint256(borrowed), require_uint256(collateralQuoted)));


    mathint preLIF = computeFactor(ltv,
                                   currentContract.LLTV,
                                   currentContract.PRE_LLTV,
                                   currentContract.PRE_LIF_1,
                                   currentContract.PRE_LIF_2) ;

    // Safe require as implementation would revert.
    require seizedAssets > 0;

    mathint seizedAssetsQuoted = require_uint256(summaryMulDivUp(seizedAssets, collateralPrice, ORACLE_SCALE()));

    mathint repaidShares = tSU(wDU(require_uint256(seizedAssetsQuoted), require_uint256(preLIF)),
                               mTotalBorrowAssets,
                               mTotalBorrowShares);

    mathint closeFactor = computeFactor(ltv,
                                        currentContract.LLTV,
                                        currentContract.PRE_LLTV,
                                        currentContract.PRE_LCF_1,
                                        currentContract.PRE_LCF_2) ;

    mathint repayableShares = wMD(pBorrowShares, require_uint256(closeFactor));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);
    assert (!priceChanged && repaidShares > repayableShares ) => lastReverted;

}
