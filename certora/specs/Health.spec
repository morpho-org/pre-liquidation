// SPDX-License-Identifier: GPL-2.0-or-later

import "ConsistentInstantiation.spec";
import "SummaryLib.spec";

methods {
    // In this specs, it is assumed are no callbacks after a pre-liquidation.
    function _.onPreLiquidate(uint256, bytes) external => NONDET;

    // It is assumed that ERC20 transfers are safe.
    function _.transfer(address, uint256) external => HAVOC_ECF;
    function _.transferFrom(address, address, uint256) external => HAVOC_ECF;

    function _.price() external => constantPrice expect uint256;

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

    function preLIF(address) external returns uint256 envfree;
    function preLCF(address) external returns uint256 envfree;
}

persistent ghost uint256 constantPrice;

rule preLIFBounded(env e, address borrower){
    // Avoid division by zero.
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();
    requireInvariant hashOfMarketParamsOf();

    require MORPHO.lastUpdate(currentContract.ID) == e.block.timestamp;
    require borrower != 0;

    assert currentContract.PRE_LIF_1 <= preLIF(borrower);
    assert preLIF(borrower) <= currentContract.PRE_LIF_2;
}

rule preLCFBounded(env e, address borrower){
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();
    requireInvariant hashOfMarketParamsOf();

    require MORPHO.lastUpdate(currentContract.ID) == e.block.timestamp;
    require borrower != 0;

    assert currentContract.PRE_LCF_1 <= preLCF(borrower);
    assert preLCF(borrower) <= currentContract.PRE_LCF_2;
}

rule positionDoesntDegrade(env e,address borrower, uint256 seizedAssetsInput, uint256 repaidSharesInput, bytes data) {
    // Avoid division by zero.
    requireInvariant preLltvConsistent();
    requireInvariant preLCFConsistent();
    requireInvariant preLIFConsistent();
    requireInvariant hashOfMarketParamsOf();

    // Assume no callback.
    require data.length == 0;

    // We place ourselves at the last block for getting the following variables.
    require MORPHO.lastUpdate(currentContract.ID) == e.block.timestamp;

    uint256 borrowerShares = MORPHO.borrowShares(currentContract.ID, borrower);
    // Safe require because of the sumBorrowSharesCorrect invariant proven in the morpho-blue repository.
    require borrowerShares <= MORPHO.totalBorrowShares(currentContract.ID);

    uint256 borrowerCollateral = MORPHO.collateral(currentContract.ID, borrower);

    uint256 lif;
    // Safe require as it proven in rule preLIFBounded.
    require currentContract.PRE_LIF_1 <= lif && lif <= currentContract.PRE_LIF_2;

    uint256 lcf;
    // Safe require as it proven in rule preLCFBounded.
    require currentContract.PRE_LCF_1 <= lcf && lcf <= currentContract.PRE_LCF_2;

    uint256 virtualTotalAssets = MORPHO.virtualTotalBorrowAssets(currentContract.ID);
    uint256 virtualTotalShares = MORPHO.virtualTotalBorrowShares(currentContract.ID);

    preLiquidate(e, borrower, seizedAssetsInput, repaidSharesInput, lif, lcf, data);

    uint256 newBorrowerShares = MORPHO.borrowShares(currentContract.ID, borrower);
    uint256 newBorrowerCollateral = MORPHO.collateral(currentContract.ID, borrower);
    uint256 repaidShares = assert_uint256(borrowerShares - newBorrowerShares);
    uint256 seizedAssets = assert_uint256(borrowerCollateral - newBorrowerCollateral);
    uint256 newVirtualTotalAssets = MORPHO.virtualTotalBorrowAssets(currentContract.ID);
    uint256 newVirtualTotalShares = MORPHO.virtualTotalBorrowShares(currentContract.ID);

    // Hint for the prover to show that there is no bad debt.
    assert newBorrowerCollateral != 0 || newBorrowerShares == 0;
    // Hint for the prover about the ratio used to close the position.
    assert repaidShares * borrowerCollateral >= seizedAssets * borrowerShares;
    // Prove that the ratio of shares of debt over collateral is smaller after the liquidation or that it has been completely liquidated.
    assert borrowerShares * newBorrowerCollateral >= newBorrowerShares * borrowerCollateral;
    // Prove that the value of borrow shares is smaller after the liquidation.
    // Note that this is only shown for the case where there are still borrow positions on the markets.
    assert assert_uint256(newVirtualTotalAssets) > 1 => newVirtualTotalShares * virtualTotalAssets >= newVirtualTotalAssets * virtualTotalShares;
}
