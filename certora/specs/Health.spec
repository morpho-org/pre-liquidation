// SPDX-License-Identifier: GPL-2.0-or-later

import "ConsistentInstantiation.spec";
import "SummaryLib.spec";

using Morpho as MORPHO;

methods {
    function _.onMorphoRepay(uint256,bytes) external => DISPATCHER(true);
    function _.price() external => mockPrice() expect uint256;

    function marketParams() internal returns (PreLiquidation.MarketParams memory)
        => summaryMarketParams();
    function lastLtv() external returns uint256 envfree;
    function lastLtvAfter() external returns uint256 envfree;

    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
      returns (uint256, uint128, uint128) envfree;
    function MORPHO.repay(PreLiquidation.MarketParams marketParams,
                           uint256 assets,
                           uint256 shares,
                           address onBehalf,
                           bytes data
                          ) external returns (uint256, uint256)
        => summaryMorphoRepay(marketParams, assets, shares, onBehalf,data);
    function MORPHO.extSloads(bytes32[]) external
        returns bytes32[] => NONDET DELETE;
    function MORPHO.accrueInterest(PreLiquidation.MarketParams) external =>
        CONSTANT;

    function UtilsLib.exactlyOneZero(uint256 a, uint256 b) internal
        returns bool => summaryExactlyOneZero(a,b);

    function MathLib.mulDivDown(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryMulDivDown(a,b,c) ALL;
    function MathLib.wMulDown(uint256 a, uint256 b) internal
        returns uint256 => summaryWMulDown(a,b) ALL;
    function MathLib.wDivUp(uint256 a, uint256 b) internal
        returns uint256 => summaryWDivUp(a,b) ALL;
    function MathLib.wDivDown(uint256 a, uint256 b) internal
        returns uint256 => summaryWDivDown(a,b) ALL;
    function MathLib.mulDivUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryMulDivUp(a,b,c) ALL;

    function SharesMathLib.toSharesUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToSharesUp(a,b,c);
    function SharesMathLib.toAssetsUp(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToAssetsUp(a,b,c);
    function SharesMathLib.toAssetsDown(uint256 a, uint256 b, uint256 c) internal
        returns uint256 => summaryToAssetsDown(a,b,c);

    function libId(PreLiquidation.MarketParams) external returns PreLiquidation.Id envfree;
}

function summaryMorphoRepay(
                            PreLiquidation.MarketParams marketParams,
                            uint256 assets,
                            uint256 shares,
                            address onBehalf,
                            bytes data
) returns (uint256, uint256)
{
    uint256 mTotalBorrowAssets;
    uint256 mTotalBorrowShares;
    uint256 mLastUpdate;

    uint256 repaidAssets;

    assert libId(marketParams) == currentContract.ID;
    assert assets == 0;
    assert shares != 0;
    assert data.length != 0;
    require onBehalf != 0;

    (_, _, mTotalBorrowAssets, mTotalBorrowShares, mLastUpdate, _) = MORPHO.market(currentContract.ID);
    // assert mLastUpdate > 0;

    repaidAssets = summaryToAssetsUp(shares, mTotalBorrowAssets, mTotalBorrowShares);

    return (repaidAssets, shares);
}

// Check correctness of applying idToMarketParams() to an identifier.
invariant hashOfMarketParamsOf()
    libId(summaryMarketParams()) == currentContract.ID
{
    preserved {
        requireInvariant preLIFNotZero();
    }
}

rule positionDoesntDegrade(env e,address borrower, uint256 seizedAssets, bytes data) {
    // Market value.
    uint256 mLastUpdate;

    // Avoid division by zero.
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();

    // Ensure consisitent positions.
    requireInvariant hashOfMarketParamsOf();

    // Ensure no callback is performed.
    require data.lenght == 0;

    (_, _, _, _, mLastUpdate, _) = MORPHO.market(currentContract.ID);

    // Ensure that no interest is accumulated.
    require mLastUpdate == e.block.timestamp;

    preLiquidate(e, borrower, seizedAssets, 0, data);

    require !priceChanged;
    assert lastLtvAfter() <= lastLtv();
}
