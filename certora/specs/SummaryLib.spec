definition ORACLE_PRICE_SCALE() returns uint256 = 10^36;

definition VIRTUAL_SHARES() returns uint256 = 10^6;

definition VIRTUAL_ASSETS() returns uint256 = 1;

function summaryWMulDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, y, WAD());
}

function summaryWDivDown(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivDown(x, WAD(), y);
}

function summaryMulDivUp(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d-1)) / d);
}

function summaryWDivUp(uint256 x,uint256 y) returns uint256 {
    return summaryMulDivUp(x, WAD(), y);
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
