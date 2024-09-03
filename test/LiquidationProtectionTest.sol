// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import {LiquidationProtection, SubscriptionParams} from "../src/LiquidationProtection.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract LiquidationProtectionTest is Test {
    uint256 internal constant BLOCK_TIME = 12;

    address internal BORROWER;
    address internal LIQUIDATOR;

    LiquidationProtection internal liquidationProtection;
    Id internal marketId;
    MarketParams internal market;
    IMorpho morpho;
    IERC20 loanToken;
    IERC20 collateralToken;

    function setUp() public virtual {
        BORROWER = makeAddr("Borrower");
        LIQUIDATOR = makeAddr("Liquidator");

        address MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
        morpho = IMorpho(MORPHO);

        marketId = Id.wrap(0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e); // wstETH/WETH (96.5%)
        market = morpho.idToMarketParams(marketId);
        loanToken = IERC20(market.loanToken);
        collateralToken = IERC20(market.collateralToken);

        liquidationProtection = new LiquidationProtection();

        vm.startPrank(BORROWER);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);

        uint256 collateralAmount = 1 * 10 ** 18;
        deal(address(collateralToken), BORROWER, collateralAmount);
        morpho.supplyCollateral(market, collateralAmount, BORROWER, hex"");
        uint256 borrowAmount = 5 * 10 ** 17;
        morpho.borrow(market, borrowAmount, 0, BORROWER, BORROWER);

        morpho.setAuthorization(address(liquidationProtection), true);

        vm.startPrank(LIQUIDATOR);
        deal(address(loanToken), LIQUIDATOR, 2 * borrowAmount);
        loanToken.approve(address(liquidationProtection), type(uint256).max);
        collateralToken.approve(address(liquidationProtection), type(uint256).max);
    }

    function testSetSubscription() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory params;
        params.slltv = 90 * 10 ** 16; // 90%
        params.closeFactor = 10 ** 18; // 100%
        params.liquidationIncentive = 10 ** 16; // 1%
        params.isValid = true;

        liquidationProtection.subscribe(marketId, params);

        bytes32 subscriptionId = liquidationProtection.computeSubscriptionId(BORROWER, marketId);
        (uint256 slltv, uint256 closeFactor, uint256 liquidationIncentive, bool isValid) =
            liquidationProtection.subscriptions(subscriptionId);
        assertEq(params.slltv, slltv);
        assertEq(params.closeFactor, closeFactor);
        assertEq(params.liquidationIncentive, liquidationIncentive);
        assertEq(params.isValid, isValid);
    }

    function testRemoveSubscription() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory params;
        params.slltv = 90 * 10 ** 16; // 90%
        params.closeFactor = 10 ** 18; // 100%
        params.liquidationIncentive = 10 ** 16; // 1%

        liquidationProtection.subscribe(marketId, params);

        liquidationProtection.unsubscribe(marketId);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(bytes("Non-valid subscription"));
        liquidationProtection.liquidate(market, BORROWER, 0, 0, hex"");
    }

    function testSoftLiquidation() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory params;
        params.slltv = 10 * 10 ** 16; // 10%
        params.closeFactor = 10 ** 18; // 100%
        params.liquidationIncentive = 10 ** 16; // 1%
        params.isValid = true;

        liquidationProtection.subscribe(marketId, params);

        vm.startPrank(LIQUIDATOR);
        Position memory position = morpho.position(marketId, BORROWER);
        liquidationProtection.liquidate(market, BORROWER, 0, position.borrowShares, hex"");
    }
}
