// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import {ILiquidationProtection, SubscriptionParams} from "../src/interfaces/ILiquidationProtection.sol";
import {LiquidationProtection} from "../src/LiquidationProtection.sol";
import {LiquidationProtectionFactory} from "../src/LiquidationProtectionFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract LiquidationProtectionTest is Test {
    uint256 internal constant BLOCK_TIME = 12;

    address internal BORROWER;
    address internal LIQUIDATOR;

    LiquidationProtectionFactory internal factory;
    ILiquidationProtection internal liquidationProtection;
    Id internal marketId;
    MarketParams internal marketParams;
    IMorpho MORPHO;
    ERC20 loanToken;
    ERC20 collateralToken;

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        BORROWER = makeAddr("Borrower");
        LIQUIDATOR = makeAddr("Liquidator");

        address morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
        MORPHO = IMorpho(morpho);

        marketId = Id.wrap(0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e); // wstETH/WETH (96.5%)
        marketParams = MORPHO.idToMarketParams(marketId);
        loanToken = ERC20(marketParams.loanToken);
        collateralToken = ERC20(marketParams.collateralToken);

        factory = new LiquidationProtectionFactory(address(MORPHO));

        vm.startPrank(BORROWER);
        loanToken.approve(address(MORPHO), type(uint256).max);
        collateralToken.approve(address(MORPHO), type(uint256).max);

        uint256 collateralAmount = 1 * 10 ** 18;
        deal(address(collateralToken), BORROWER, collateralAmount);
        MORPHO.supplyCollateral(marketParams, collateralAmount, BORROWER, hex"");
        uint256 borrowAmount = 5 * 10 ** 17;
        MORPHO.borrow(marketParams, borrowAmount, 0, BORROWER, BORROWER);
    }

    function testSetSubscription() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory subscriptionParams;
        subscriptionParams.prelltv = 90 * 10 ** 16; // 90%
        subscriptionParams.closeFactor = 10 ** 18; // 100%
        subscriptionParams.liquidationIncentive = 10 ** 16; // 1%

        liquidationProtection = factory.createPreLiquidation(marketParams, subscriptionParams);

        liquidationProtection.subscribe();
        assertTrue(liquidationProtection.subscriptions(BORROWER));
    }

    function testRemoveSubscription() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory subscriptionParams;
        subscriptionParams.prelltv = 90 * 10 ** 16; // 90%
        subscriptionParams.closeFactor = 10 ** 18; // 100%
        subscriptionParams.liquidationIncentive = 10 ** 16; // 1%

        liquidationProtection = factory.createPreLiquidation(marketParams, subscriptionParams);
        liquidationProtection.subscribe();
        liquidationProtection.unsubscribe();

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(ErrorsLib.InvalidSubscription.selector);
        liquidationProtection.liquidate(marketParams, BORROWER, 0, 0, hex"");
    }

    function testSoftLiquidation() public virtual {
        vm.startPrank(BORROWER);

        SubscriptionParams memory subscriptionParams;
        subscriptionParams.prelltv = 10 * 10 ** 16; // 10%
        subscriptionParams.closeFactor = 10 ** 18; // 100%
        subscriptionParams.liquidationIncentive = 10 ** 16; // 1%

        liquidationProtection = factory.createPreLiquidation(marketParams, subscriptionParams);
        MORPHO.setAuthorization(address(liquidationProtection), true);
        liquidationProtection.subscribe();

        vm.startPrank(LIQUIDATOR);

        uint256 borrowAmount = 5 * 10 ** 17;
        deal(address(loanToken), LIQUIDATOR, 2 * borrowAmount);
        loanToken.approve(address(liquidationProtection), type(uint256).max);
        collateralToken.approve(address(liquidationProtection), type(uint256).max);

        Position memory position = MORPHO.position(marketId, BORROWER);
        liquidationProtection.liquidate(marketParams, BORROWER, 0, position.borrowShares, hex"");
    }
}
