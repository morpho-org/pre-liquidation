// SPDX-License-Identifier: GPL-2.0-or-later

import "ConsistentInstantiation.spec";
import "SummaryLib.spec";

methods {
    function _.onMorphoRepay(uint256, bytes) external => DISPATCHER(true);

    // Disregard some unresolved calls altogether.
    function _.onPreLiquidate(uint256, bytes) external => NONDET DELETE;
    function _.transfer(address, uint256) external => NONDET DELETE;
    function _.transferFrom(address, address, uint256) external => NONDET DELETE;

    function _.price() external => constantPrice expect uint256;

    function marketParams() internal returns (PreLiquidation.MarketParams memory)
        => summaryMarketParams();

    function MORPHO.extSloads(bytes32[]) external returns bytes32[] => NONDET DELETE;
    function MORPHO.market(PreLiquidation.Id) external
      returns (uint128, uint128, uint128,uint128, uint128, uint128) envfree;
    function MORPHO.position(PreLiquidation.Id, address) external
      returns (uint256, uint128, uint128) envfree;
    function MORPHO.totalBorrowShares(PreLiquidation.Id) external returns (uint256) envfree;
    function MORPHO.totalBorrowAssets(PreLiquidation.Id) external returns (uint256) envfree;

    function UtilsLib.exactlyOneZero(uint256 a, uint256 b) internal
        returns bool => summaryExactlyOneZero(a,b);
    function Util.oraclePriceScale() external returns (uint256) envfree;
    function Util.wad() external returns (uint256) envfree;

    function MORPHO.accrueInterest(PreLiquidation.MarketParams) external => NONDET;
    function Morpho._isHealthy(MorphoHarness.MarketParams memory, MorphoHarness.Id,address) internal returns (bool) => NONDET;
    function Morpho._accrueInterest(MorphoHarness.MarketParams memory, MorphoHarness.Id) internal => NONDET;
}

rule positionDoesntDegrade(env e,address borrower, uint256 seizedAssets, bytes data) {
    // Avoid division by zero.
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();
    requireInvariant hashOfMarketParamsOf();
    PreLiquidation.Id id = Util.libId(summaryMarketParams());

    // We place ourselves at the last block for getting the following variables.
    require MORPHO.lastUpdate(id) == e.block.timestamp;

    // Assume no callback.
    require data.length == 0;

    uint256 borrowerShares = MORPHO.borrowShares(id, borrower);
    // Safe require because of the sumBorrowSharesCorrect invariant.
    require borrowerShares <= MORPHO.totalBorrowShares(id);

    uint256 borrowerCollateral = MORPHO.collateral(id, borrower);

    uint256 lif;
    require currentContract.PRE_LIF_1 <= lif && lif <= currentContract.PRE_LIF_2;

    uint256 lcf;
    require lcf == Util.wad();

    uint256 virtualTotalAssets = MORPHO.virtualTotalBorrowAssets(id);
    uint256 virtualTotalShares = MORPHO.virtualTotalBorrowShares(id);
    require borrowerCollateral * constantPrice * virtualTotalShares * Util.wad() > borrowerShares * Util.oraclePriceScale() * virtualTotalAssets * currentContract.PRE_LIF_2;


    preLiquidate(e, borrower, seizedAssets, 0, lif, lcf, data);

    uint256 newBorrowerShares = MORPHO.borrowShares(id, borrower);
    uint256 newBorrowerCollateral = MORPHO.collateral(id, borrower);
    uint256 repaidShares = assert_uint256(borrowerShares - newBorrowerShares);
    uint256 newVirtualTotalAssets = MORPHO.virtualTotalBorrowAssets(id);
    uint256 newVirtualTotalShares = MORPHO.virtualTotalBorrowShares(id);

    // Hint for the prover to show that there is no bad debt realization.
    assert newBorrowerCollateral != 0;
    // Hint for the prover about the ratio used to close the position.
    assert repaidShares * borrowerCollateral >= seizedAssets * borrowerShares;
    // Prove that the ratio of shares of debt over collateral is smaller after the liquidation or that it has been completely liquidated.
    assert borrowerShares * newBorrowerCollateral >= newBorrowerShares * borrowerCollateral;
    // Prove that the value of borrow shares is smaller after the liquidation.
    // Note that this is only shown for the case where there are still borrow positions on the markets.
    assert assert_uint256(newVirtualTotalAssets - 1) > 0 => newVirtualTotalShares * virtualTotalAssets >= newVirtualTotalAssets * virtualTotalShares;
}
