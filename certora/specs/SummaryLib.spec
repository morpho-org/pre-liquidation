// SPDX-License-Identifier: GPL-2.0-or-later

using Morpho as MORPHO;

methods {
    function MORPHO.market(PreLiquidation.Id) external
        returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
        returns (uint256, uint128, uint128) envfree;
}

definition WAD() returns uint256 = 10^18;

definition ORACLE_PRICE_SCALE() returns uint256 = 10^36;

definition VIRTUAL_SHARES() returns uint256 = 10^6;

definition VIRTUAL_ASSETS() returns uint256 = 1;

function summaryWMulDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, y, WAD());
}

function summaryWDivDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, WAD(), y);
}

function summaryMulDivDown(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y)/d);
}

function summaryWDivUp(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivUp(x, WAD(), y);
}

function summaryMulDivUp(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d-1)) / d);

}


function summaryToAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256 {
    return summaryMulDivDown(shares,
                             require_uint256(totalAssets + VIRTUAL_ASSETS()),
                             require_uint256(totalShares + VIRTUAL_SHARES()));
}

function summaryToSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) returns uint256 {
    return summaryMulDivUp(assets,
                           require_uint256(totalShares + VIRTUAL_SHARES()),
                           require_uint256(totalAssets + VIRTUAL_ASSETS()));
}

function summaryToAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) returns uint256 {
    return summaryMulDivUp(shares,
                           require_uint256(totalAssets + VIRTUAL_ASSETS()),
                           require_uint256(totalShares + VIRTUAL_SHARES()));
}

function summaryMarketParams() returns PreLiquidation.MarketParams {
    PreLiquidation.MarketParams x;
    require
        x.loanToken == currentContract.LOAN_TOKEN
        && x.collateralToken == currentContract.COLLATERAL_TOKEN
        && x.oracle == currentContract.ORACLE
        && x.irm == currentContract.IRM
        && x.lltv == currentContract.LLTV;
    return x;
}

function summaryExactlyOneZero(uint256 assets, uint256 shares) returns bool {
    return (assets == 0 && shares != 0) || (assets != 0 && shares == 0);
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

function positionAsAssets (address borrower) returns (uint256, uint256) {
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;

    uint256 pBorrowShares;
    uint256 pCollateral;

    (_, _, mTotalBorrowAssets, mTotalBorrowShares,_ , _) = MORPHO.market(currentContract.ID);
    (_, pBorrowShares, pCollateral) = MORPHO.position(currentContract.ID, borrower);

    uint256 collateralPrice = mockPrice();
    uint256 collateralQuoted = require_uint256(summaryMulDivDown(pCollateral, collateralPrice, ORACLE_PRICE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    uint256 borrowed = require_uint256(summaryToAssetsUp(pBorrowShares, mTotalBorrowAssets, mTotalBorrowShares));

    return (borrowed, collateralQuoted);
}

function getLtv(address borrower) returns uint256 {
    uint256 borrowed;
    uint256 collateralQuoted;

    (borrowed, collateralQuoted) = positionAsAssets(borrower);

    return summaryWDivUp(borrowed, collateralQuoted);
}

definition computeLinearCombination(mathint ltv, mathint lltv, mathint preLltv, mathint yAtPreLltv, mathint yAtLltv)
    returns mathint = summaryWMulDown(summaryWDivDown(require_uint256(ltv - preLltv),
                                                      require_uint256(lltv - preLltv)),
                                      require_uint256(yAtLltv - yAtPreLltv)) + yAtPreLltv;
