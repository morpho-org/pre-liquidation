// SPDX-License-Identifier: GPL-2.0-or-later

definition WAD() returns uint256 = 10^18;

function summaryWMulDown(uint256 x,uint256 y) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y)/WAD());
}

function summaryWDivUp(uint256 x,uint256 y) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * WAD() + (y-1)) / y);
}


// Check that LTV <= LLTV is equivalent to borrowed <= (collateralQuoted * LLTV) / WAD.
rule borrowedLECollatQuotedTimesLLTVEqLtvLTEqLLTV {
    uint256 borrowed;
    uint256 collateralQuoted;

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    mathint ltv = summaryWDivUp(borrowed, collateralQuoted);

    assert (ltv <= currentContract.LLTV) <=> borrowed <= summaryWMulDown(collateralQuoted, currentContract.LLTV);
}

// Check that substracting the PRE_LLTV to LTV wont underflow.
rule ltvMinusPreLltvWontUnderflow {
    uint256 borrowed;
    uint256 collateralQuoted;
    uint256 preLltv;

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require (collateralQuoted > 0);

    // Safe require because the implementation would revert if borrowed threshold is not ensured.
    uint256 borrowThreshold = summaryWMulDown(collateralQuoted, preLltv);
    require (borrowed > borrowThreshold);

    uint256 ltv = summaryWDivUp(borrowed, collateralQuoted);
    assert ltv >= preLltv;
}
