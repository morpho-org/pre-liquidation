// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;


import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {IPreLiquidation, PreLiquidationParams} from "../src/interfaces/IPreLiquidation.sol";
import {IPreLiquidationCallback} from "../src/interfaces/IPreLiquidationCallback.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {PreLiquidation} from "../src/PreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

contract PreLiquidationTest is BaseTest, IPreLiquidationCallback {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    PreLiquidationFactory internal factory;
    IPreLiquidation internal preLiquidation;

    function setUp() public override {
        super.setUp();

        factory = new PreLiquidationFactory(address(MORPHO));
    }

    function preparePreLiquidation(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address liquidator
    ) public returns (uint256) {
        preLiquidationParams.preLltv = bound(preLiquidationParams.preLltv, WAD / 100, marketParams.lltv - 1);
        preLiquidationParams.closeFactor = bound(preLiquidationParams.closeFactor, WAD / 100, WAD - 1);
        preLiquidationParams.preLiquidationIncentive = bound(preLiquidationParams.preLiquidationIncentive, 1, WAD / 10);
        preLiquidationParams.preLiquidationOracle = marketParams.oracle;

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowLiquidationThreshold = collateralAmount.mulDivDown(
            IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE
        ).wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLiquidationParams.preLltv);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        deal(address(loanToken), SUPPLIER, borrowAmount);
        vm.prank(SUPPLIER);
        MORPHO.supply(marketParams, uint128(borrowAmount), 0, SUPPLIER, hex"");

        deal(address(collateralToken), BORROWER, collateralAmount);
        vm.startPrank(BORROWER);
        MORPHO.supplyCollateral(marketParams, collateralAmount, BORROWER, hex"");

        vm.startPrank(liquidator);
        deal(address(loanToken), liquidator, type(uint256).max);
        loanToken.approve(address(preLiquidation), type(uint256).max);
        collateralToken.approve(address(preLiquidation), type(uint256).max);

        vm.expectRevert(ErrorsLib.NotPreLiquidatablePosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");

        vm.startPrank(BORROWER);
        MORPHO.borrow(marketParams, borrowAmount, 0, BORROWER, BORROWER);
        MORPHO.setAuthorization(address(preLiquidation), true);
        vm.stopPrank();

        return collateralPrice;
    }

    function testHighLltv(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams.preLltv = bound(preLiquidationParams.preLltv, marketParams.lltv, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLltvTooHigh.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testNonexistentMarket(Id _id, PreLiquidationParams memory preLiquidationParams) public virtual {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NonexistentMarket.selector));
        factory.createPreLiquidation(_id, preLiquidationParams);
    }

    function testPreLiquidation(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        uint256 collateralPrice =
            preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 repayableShares = position.borrowShares.wMulDown(preLiquidationParams.closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            preLiquidationParams.preLiquidationIncentive
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 0, hex"");

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, seizedAssets, repayableShares, hex"");

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }

    function testPreLiquidationCallback(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        uint256 collateralPrice =
            preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, address(this));

        Position memory position = MORPHO.position(marketParams.id(), BORROWER);
        Market memory market = MORPHO.market(marketParams.id());

        uint256 repayableShares = position.borrowShares.wMulDown(preLiquidationParams.closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares)
            .wMulDown(preLiquidationParams.preLiquidationIncentive).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        bytes memory data = abi.encode(this.testPreLiquidationCallback.selector, hex"");

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, data);
    }

    function onPreLiquidate(uint256, bytes memory data) external pure {
        bytes4 selector;
        (selector,) = abi.decode(data, (bytes4, bytes));
        require(selector == this.testPreLiquidationCallback.selector);
    }
}
