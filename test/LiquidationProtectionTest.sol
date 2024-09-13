// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {ILiquidationProtection, SubscriptionParams} from "../src/interfaces/ILiquidationProtection.sol";
import {LiquidationProtection} from "../src/LiquidationProtection.sol";
import {LiquidationProtectionFactory} from "../src/LiquidationProtectionFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract LiquidationProtectionTest is BaseTest {
    using MarketParamsLib for MarketParams;

    LiquidationProtectionFactory internal factory;
    ILiquidationProtection internal liquidationProtection;
    SubscriptionParams subscription;

    function setUp() public override {
        super.setUp();

        factory = new LiquidationProtectionFactory(address(MORPHO));
        subscription = SubscriptionParams(0.7 ether, 1 ether, 0.01 ether); // prelltv=70%, closrfactor=100%, incentive=1%
        liquidationProtection = factory.createPreLiquidation(market, subscription);

        uint256 collateralAmount = 1 ether;
        deal(address(collateralToken), BORROWER, collateralAmount);
        vm.prank(BORROWER);
        MORPHO.supplyCollateral(market, collateralAmount, BORROWER, hex"");

        uint256 borrowAmount = 0.75 ether;
        deal(address(loanToken), SUPPLIER, borrowAmount);

        vm.prank(SUPPLIER);
        MORPHO.supply(market, borrowAmount, 0, SUPPLIER, hex"");

        vm.prank(BORROWER);
        MORPHO.borrow(market, borrowAmount, 0, BORROWER, BORROWER);
    }

    function testSetSubscription() public virtual {
        vm.startPrank(BORROWER);
        liquidationProtection.subscribe();
        assertTrue(liquidationProtection.subscriptions(BORROWER));
    }

    function testRemoveSubscription() public virtual {
        vm.startPrank(BORROWER);
        liquidationProtection.subscribe();
        liquidationProtection.unsubscribe();

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(ErrorsLib.InvalidSubscription.selector);
        liquidationProtection.preliquidate(BORROWER, 0, 0, hex"");
    }

    function testSoftLiquidation() public virtual {
        vm.startPrank(BORROWER);
        MORPHO.setAuthorization(address(liquidationProtection), true);
        liquidationProtection.subscribe();

        vm.startPrank(LIQUIDATOR);

        uint256 borrowAmount = 0.75 ether;
        deal(address(loanToken), LIQUIDATOR, 2 * borrowAmount);
        loanToken.approve(address(liquidationProtection), type(uint256).max);
        collateralToken.approve(address(liquidationProtection), type(uint256).max);

        Position memory position = MORPHO.position(market.id(), BORROWER);
        liquidationProtection.preliquidate(BORROWER, 0, position.borrowShares, hex"");
    }
}
