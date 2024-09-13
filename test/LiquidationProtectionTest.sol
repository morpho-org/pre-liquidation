// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {ILiquidationProtection, SubscriptionParams} from "../src/interfaces/ILiquidationProtection.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {LiquidationProtection} from "../src/LiquidationProtection.sol";
import {LiquidationProtectionFactory} from "../src/LiquidationProtectionFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

contract LiquidationProtectionTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    LiquidationProtectionFactory internal factory;
    ILiquidationProtection internal liquidationProtection;

    function setUp() public override {
        super.setUp();

        factory = new LiquidationProtectionFactory(address(MORPHO));
    }

    function testSetSubscription(SubscriptionParams calldata subscription) public virtual {
        vm.assume(subscription.prelltv < market.lltv);
        liquidationProtection = factory.createPreLiquidation(market, subscription);

        vm.startPrank(BORROWER);
        liquidationProtection.subscribe();
        assertTrue(liquidationProtection.subscriptions(BORROWER));
    }

    function testRemoveSubscription(SubscriptionParams calldata subscription) public virtual {
        vm.assume(subscription.prelltv < market.lltv);
        liquidationProtection = factory.createPreLiquidation(market, subscription);

        vm.startPrank(BORROWER);

        liquidationProtection.subscribe();
        liquidationProtection.unsubscribe();

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(ErrorsLib.InvalidSubscription.selector);
        liquidationProtection.preLiquidate(BORROWER, 0, 0, hex"");
    }

    function testSoftLiquidation(SubscriptionParams memory subscription, uint256 collateralAmount, uint256 borrowAmount)
        public
        virtual
    {
        subscription.prelltv = bound(subscription.prelltv, WAD / 100, market.lltv - 1);
        subscription.closeFactor = bound(subscription.closeFactor, WAD / 100, WAD - 1);
        subscription.preLiquidationIncentive = bound(subscription.preLiquidationIncentive, 1, WAD / 10);
        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        liquidationProtection = factory.createPreLiquidation(market, subscription);

        uint256 collateralPrice = IOracle(market.oracle).price();
        uint256 maxBorrow =
            collateralAmount.mulDivDown(IOracle(market.oracle).price(), ORACLE_PRICE_SCALE).wMulDown(market.lltv);
        uint256 minBorrow =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(subscription.prelltv);
        borrowAmount = bound(borrowAmount, minBorrow + 1, maxBorrow);

        deal(address(loanToken), SUPPLIER, borrowAmount);
        vm.prank(SUPPLIER);
        MORPHO.supply(market, uint128(borrowAmount), 0, SUPPLIER, hex"");

        deal(address(collateralToken), BORROWER, collateralAmount);
        vm.startPrank(BORROWER);
        MORPHO.supplyCollateral(market, collateralAmount, BORROWER, hex"");
        MORPHO.borrow(market, borrowAmount, 0, BORROWER, BORROWER);
        MORPHO.setAuthorization(address(liquidationProtection), true);

        liquidationProtection.subscribe();

        vm.startPrank(LIQUIDATOR);
        deal(address(loanToken), LIQUIDATOR, type(uint256).max);
        loanToken.approve(address(liquidationProtection), type(uint256).max);
        collateralToken.approve(address(liquidationProtection), type(uint256).max);

        Position memory position = MORPHO.position(market.id(), BORROWER);
        Market memory m = MORPHO.market(market.id());

        uint256 repayableShares = position.borrowShares.wMulDown(subscription.closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            subscription.preLiquidationIncentive
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        liquidationProtection.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }
}
