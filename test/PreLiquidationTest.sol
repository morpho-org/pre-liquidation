// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {IPreLiquidation, PreLiquidationParams} from "../src/interfaces/IPreLiquidation.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {PreLiquidation} from "../src/PreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

contract PreLiquidationTest is BaseTest {
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

    function testSetSubscription(PreLiquidationParams calldata preLiquidationParams) public virtual {
        vm.assume(preLiquidationParams.prelltv < market.lltv);
        preLiquidation = factory.createPreLiquidation(market, preLiquidationParams);

        vm.startPrank(BORROWER);
        preLiquidation.setSubscription(true);
        assertTrue(preLiquidation.subscriptions(BORROWER));
    }

    function testRemoveSubscription(PreLiquidationParams calldata preLiquidationParams) public virtual {
        vm.assume(preLiquidationParams.prelltv < market.lltv);
        preLiquidation = factory.createPreLiquidation(market, preLiquidationParams);

        vm.startPrank(BORROWER);

        preLiquidation.setSubscription(true);
        preLiquidation.setSubscription(false);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(ErrorsLib.InvalidSubscription.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 0, hex"");
    }

    function testPreLiquidation(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        preLiquidationParams.prelltv = bound(preLiquidationParams.prelltv, WAD / 100, market.lltv - 1);
        preLiquidationParams.closeFactor = bound(preLiquidationParams.closeFactor, WAD / 100, WAD - 1);
        preLiquidationParams.preLiquidationIncentive = bound(preLiquidationParams.preLiquidationIncentive, 1, WAD / 10);
        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        preLiquidation = factory.createPreLiquidation(market, preLiquidationParams);

        uint256 collateralPrice = IOracle(market.oracle).price();
        uint256 borrowLiquidationThreshold =
            collateralAmount.mulDivDown(IOracle(market.oracle).price(), ORACLE_PRICE_SCALE).wMulDown(market.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLiquidationParams.prelltv);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        deal(address(loanToken), SUPPLIER, borrowAmount);
        vm.prank(SUPPLIER);
        MORPHO.supply(market, uint128(borrowAmount), 0, SUPPLIER, hex"");

        deal(address(collateralToken), BORROWER, collateralAmount);
        vm.startPrank(BORROWER);
        MORPHO.supplyCollateral(market, collateralAmount, BORROWER, hex"");
        MORPHO.borrow(market, borrowAmount, 0, BORROWER, BORROWER);
        MORPHO.setAuthorization(address(preLiquidation), true);

        preLiquidation.setSubscription(true);

        vm.startPrank(LIQUIDATOR);
        deal(address(loanToken), LIQUIDATOR, type(uint256).max);
        loanToken.approve(address(preLiquidation), type(uint256).max);
        collateralToken.approve(address(preLiquidation), type(uint256).max);

        Position memory position = MORPHO.position(market.id(), BORROWER);
        Market memory m = MORPHO.market(market.id());

        uint256 repayableShares = position.borrowShares.wMulDown(preLiquidationParams.closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            preLiquidationParams.preLiquidationIncentive
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }
}
