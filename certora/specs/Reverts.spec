// SPDX-License-Identifier: GPL-2.0-or-later

import "ConsistentInstantiation.spec";

methods {
    function _.price() external => mockPrice() expect uint256;

    function MathLib.mulDivDown(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryMulDivDown(a,b,c);
    function MathLib.mulDivUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryMulDivUp(a,b,c);

    function SharesMathLib.toSharesUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToSharesUp(a,b,c);
    function SharesMathLib.toAssetsUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToAssetsUp(a,b,c);
}

// Checks that onMorphoRepay is only triggered by Morpho.
rule onMorphoRepaySenderValidation(env e, uint256 repaidAssets, bytes data) {
    onMorphoRepay@withrevert(e, repaidAssets, data);
    assert e.msg.sender != currentContract.MORPHO => lastReverted;
}

// Check that preLiquidate reverts when its inputs are not validated.
rule preLiquidateInputValidation(env e, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data) {
    // Avoid absurd divisions by zero.
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    preLiquidate@withrevert(e, borrower, seizedAssets, repaidShares, data);
    assert !summaryExactlyOneZero(seizedAssets, repaidShares) => lastReverted;
}

// Check that collateralQuoted == 0 would revert by failing require-statements.
rule zeroCollateralQuotedReverts(env e, address borrower, uint256 seizedAssets, bytes data) {
    requireInvariant preLltvConsistent();

    uint256 collateralQuoted;
    uint256 borrowed;

    uint256 higherBound = summaryWMulDown(collateralQuoted, currentContract.LLTV);
    uint256 lowerBound = summaryWMulDown(collateralQuoted, currentContract.PRE_LLTV);

    assert  collateralQuoted == 0 => (lowerBound >= borrowed || borrowed > higherBound);
}

// Check that pre-liquidating a position such that LTV <= PRE_LLTV reverts.
// This also implies that LTV > PRE_LLTV when borrowed > collateralQuoted.summaryWMulDown(PRE_LLTV).
rule nonLiquidatablePositionReverts(env e,address borrower, uint256 seizedAssets, bytes data) {
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    uint256 mLastUpdate;
    (_, _, _, _, mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    mathint ltv = getLtv(borrower);

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert ltv <= currentContract.PRE_LLTV => lastReverted;
}

// Check that pre-liquidating a position such that LTV > LLTV would revert.
rule liquidatablePositionReverts(env e, address borrower, uint256 seizedAssets, bytes data) {
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    uint256 mLastUpdate;
    (_, _, _, _, mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    mathint ltv = getLtv(borrower);

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert ltv > currentContract.LLTV => lastReverted;
}

// Check that a pre-liquidation that repays more shares than available or allowed by the preLCF reverts.
rule excessivePreliquidationWithAssetsReverts(env e, address borrower, uint256 seizedAssets, bytes data) {
    // Market values.
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    // Position values.
    uint256 pBorrowShares;

    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    (_, _, mTotalBorrowAssets, mTotalBorrowShares, mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    (_, pBorrowShares, _) = MORPHO.position(currentContract.ID, borrower);

    mathint ltv = getLtv(borrower);

    mathint preLIF = computeLinearCombination(ltv,
                                              currentContract.LLTV,
                                              currentContract.PRE_LLTV,
                                              currentContract.PRE_LIF_1,
                                              currentContract.PRE_LIF_2) ;

    // Safe require as implementation would revert with InconsistentInput.
    require seizedAssets > 0;

    mathint seizedAssetsQuoted = require_uint256(summaryMulDivUp(seizedAssets, mockPrice(), ORACLE_PRICE_SCALE()));

    mathint repaidShares = summaryToSharesUp(summaryWDivUp(require_uint256(seizedAssetsQuoted), require_uint256(preLIF)),
                               mTotalBorrowAssets,
                               mTotalBorrowShares);

    mathint closeFactor = computeLinearCombination(ltv,
                                                   currentContract.LLTV,
                                                   currentContract.PRE_LLTV,
                                                   currentContract.PRE_LCF_1,
                                                   currentContract.PRE_LCF_2) ;

    mathint repayableShares = summaryWMulDown(pBorrowShares, require_uint256(closeFactor));

    preLiquidate@withrevert(e, borrower, seizedAssets, 0, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert repaidShares > repayableShares => lastReverted;

}

// Check that repaying more shares than available or allowed by the preLCF would revert.
rule excessivePreliquidationWithSharesReverts(env e, address borrower, uint256 repaidShares, bytes data) {
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    uint256 mLastUpdate;
    (_, _, _, _, mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    uint256 pBorrowShares;
    (_, pBorrowShares, _) = MORPHO.position(currentContract.ID, borrower);

    mathint ltv = getLtv(borrower);

    // Safe require as implementation would revert with InconsistentInput.
    require repaidShares > 0;

    mathint closeFactor = computeLinearCombination(ltv,
                                                   currentContract.LLTV,
                                                   currentContract.PRE_LLTV,
                                                   currentContract.PRE_LCF_1,
                                                   currentContract.PRE_LCF_2) ;

    mathint repayableShares = summaryWMulDown(pBorrowShares, require_uint256(closeFactor));

    preLiquidate@withrevert(e, borrower, 0, repaidShares, data);

    // Ensure the price is unchanged in the preLiquidate call.
    require !priceChanged;

    assert repaidShares > repayableShares => lastReverted;
}
