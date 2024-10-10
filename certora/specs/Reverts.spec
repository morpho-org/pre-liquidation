// SPDX-License-Identifier: GPL-2.0-or-later

import "ConsistentInstantiation.spec";

using Morpho as MORPHO;

methods {
    function _.position(PreLiquidation.Id, address) external => DISPATCHER(true);
    function _.accrueInterest(PreLiquidation.MarketParams) external => DISPATCHER(true);
    function _.borrowRate(PreLiquidation.MarketParams, PreLiquidation.Id) external => HAVOC_ECF;
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
      returns (uint256, uint128, uint128) envfree;
    function MORPHO.idToMarketParams(PreLiquidation.Id) external
      returns (address, address, address, address, uint256) envfree;
    function _.price() external => mockPrice() expect uint256;
    function MathLib.mulDivDown(uint256 a, uint256 b, uint256 c) internal
        returns uint256
        => summaryMulDivDown(a,b,c);
    function MathLib.mulDivUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryMulDivUp(a,b,c);
    function SharesMathLib.toSharesUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToSharesUp(a,b,c);
    function SharesMathLib.toAssetsUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToAssetsUp(a,b,c);

}

persistent ghost uint256 lastPrice;
persistent ghost bool priceChanged;

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

function summaryToAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256 {
    return summaryMulDivUp(shares,
                           require_uint256(totalAssets + (10^6)),
                           require_uint256(totalShares + (10^6)));
}

function summaryToSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) returns uint256 {
    return summaryMulDivUp(assets,
                           require_uint256(totalShares + (10^6)),
                           require_uint256(totalAssets + (10^6)));
}

definition ORACLE_SCALE() returns uint256  = 10^36;

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool =
  (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

definition wDivUp(uint256 x,uint256 y) returns uint256 = summaryMulDivUp(x, WAD(), y);

definition wMulDown(uint256 x,uint256 y) returns uint256 = summaryMulDivDown(x, y, WAD());

definition computeLinearCombination(mathint ltv, mathint lltv, mathint preLltv, mathint yAtPreLltv, mathint yAtLltv)
    returns mathint =
    wMulDown(wDivDown(require_uint256(ltv - preLltv),
            require_uint256(lltv - preLltv)),
        require_uint256(yAtLltv - yAtPreLltv)) + yAtPreLltv;

// Checks that onMorphoRepay is only triggered by Morpho
rule onMorphoRepaySenderValidation(env e, uint256 repaidAssets, bytes data) {
    onMorphoRepay@withrevert(e, repaidAssets, data);
    assert e.msg.sender != currentContract.MORPHO => lastReverted;
}

// Check that preLiquidate reverts when its inputs are not validated.
rule preLiquidateInputValidation(env e, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data) {
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();
    preLiquidate@withrevert(e, borrower, seizedAssets, repaidShares, data);
    assert !exactlyOneZero(seizedAssets, repaidShares) => lastReverted;
}

// Check that collateralQuoted == 0 would revert by failing require-statements.
rule zeroCollateralQuotedReverts(env e, address borrower, uint256 seizedAssets, bytes data) {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    uint256 collateralPrice;

    requireInvariant preLltvConsistent();

    uint256 collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));
    uint256 borrowed = require_uint256(summaryToAssetsUp(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));

    uint256 higherBound = wMulDown(collateralQuoted, currentContract.LLTV);
    uint256 lowerBound = wMulDown(collateralQuoted, currentContract.PRE_LLTV);

    assert  collateralQuoted == 0 => (lowerBound >= borrowed || borrowed > higherBound);
}

// Check that pre-liqudidating a position such that ltv <= PRE_LLTV would revert.
// This also implies that ltv <= PRE_LLTV is equivalent to borrowed > collateralQuoted.wMulDown(PRE_LLTV).
rule nonLiquidatablePositionReverts(env e,address borrower, uint256 seizedAssets, bytes data) {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    (_, _, mTotalBorrowAssets,mTotalBorrowShares,mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    uint256 collateralPrice = mockPrice();

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    mathint borrowed = require_uint256(summaryToAssetsUp(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint ltv = require_uint256(wDivUp(require_uint256(borrowed), require_uint256(collateralQuoted)));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert ltv <= currentContract.PRE_LLTV => lastReverted;
}

// Check that pre-liqudidating a position such that ltv > LLTV would revert.
rule liquidatablePositionReverts(env e,address borrower, uint256 seizedAssets, bytes data) {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    // Position values.
    uint256 pBorrowShares;
    uint256 pCollateral;

    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    (_, _, mTotalBorrowAssets,mTotalBorrowShares,mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    uint256 collateralPrice = mockPrice();

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    mathint borrowed = require_uint256(summaryToAssetsUp(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint ltv = require_uint256(wDivUp(require_uint256(borrowed), require_uint256(collateralQuoted)));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert  ltv > currentContract.LLTV => lastReverted;
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

    uint256 collateralPrice = mockPrice();

    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    mathint collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    mathint borrowed = require_uint256(summaryToAssetsUp(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));
    mathint ltv = require_uint256(wDivUp(require_uint256(borrowed), require_uint256(collateralQuoted)));


    mathint preLIF = computeLinearCombination(ltv,
                                              currentContract.LLTV,
                                              currentContract.PRE_LLTV,
                                              currentContract.PRE_LIF_1,
                                              currentContract.PRE_LIF_2) ;

    // Safe require as implementation would revert with InconsistentInput.
    require seizedAssets > 0;

    mathint seizedAssetsQuoted = require_uint256(summaryMulDivUp(seizedAssets, collateralPrice, ORACLE_SCALE()));

    mathint repaidShares = summaryToSharesUp(wDivUp(require_uint256(seizedAssetsQuoted), require_uint256(preLIF)),
                               mTotalBorrowAssets,
                               mTotalBorrowShares);

    mathint closeFactor = computeLinearCombination(ltv,
                                                   currentContract.LLTV,
                                                   currentContract.PRE_LLTV,
                                                   currentContract.PRE_LCF_1,
                                                   currentContract.PRE_LCF_2) ;

    mathint repayableShares = wMulDown(pBorrowShares, require_uint256(closeFactor));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert repaidShares > repayableShares => lastReverted;

}
