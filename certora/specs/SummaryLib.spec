// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as MORPHO;
using Util as Util;

methods {
    function MORPHO.virtualTotalBorrowAssets(PreLiquidation.Id) external returns(uint256) envfree;
    function MORPHO.virtualTotalBorrowShares(PreLiquidation.Id) external returns(uint256) envfree;
    function MORPHO.borrowShares(PreLiquidation.Id, address) external returns (uint256) envfree;
    function MORPHO.collateral(PreLiquidation.Id, address) external returns (uint256) envfree;
    function MORPHO.lastUpdate(PreLiquidation.Id) external returns (uint256) envfree;
}

definition WAD() returns uint256 = 10^18;

definition ORACLE_PRICE_SCALE() returns uint256 = 10^36;

function summaryWMulDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, y, WAD());
}

function summaryWDivDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, WAD(), y);
}

function summaryMulDivDown(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y) / d);
}

function summaryWDivUp(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivUp(x, WAD(), y);
}

function summaryMulDivUp(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d - 1)) / d);
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


// Ensure this function is only used when no interest is accrued, or enforce that the last update matches the current timestamp.
function positionAsAssets (address borrower) returns (uint256, uint256) {
    uint256 borrowerShares = MORPHO.borrowShares(currentContract.ID, borrower);
    uint256 borrowerCollateral = MORPHO.collateral(currentContract.ID, borrower);

    uint256 collateralQuoted = require_uint256(summaryMulDivDown(borrowerCollateral, mockPrice(), ORACLE_PRICE_SCALE()));

    // Safe require because the implementation would revert, see rule zeroCollateralQuotedReverts.
    require collateralQuoted > 0;

    uint256 totalAssets = MORPHO.virtualTotalBorrowAssets(currentContract.ID);
    uint256 totalShares = MORPHO.virtualTotalBorrowShares(currentContract.ID);
    uint256 borrowed = require_uint256(summaryMulDivUp(borrowerShares, totalAssets, totalShares));

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
