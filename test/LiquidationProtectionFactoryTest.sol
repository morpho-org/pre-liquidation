// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {SubscriptionParams, ILiquidationProtection} from "../src/interfaces/ILiquidationProtection.sol";
import {LiquidationProtectionFactory} from "../src/LiquidationProtectionFactory.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract LiquidationProtectionFactoryTest is BaseTest {
    LiquidationProtectionFactory factory;

    function setUp() public override {
        super.setUp();
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new LiquidationProtectionFactory(address(0));
    }

    function testCreatePreLiquidation(SubscriptionParams calldata subscription) public {
        vm.assume(subscription.prelltv < lltv);

        factory = new LiquidationProtectionFactory(address(MORPHO));
        ILiquidationProtection liquidationProtection = factory.createPreLiquidation(market, subscription);

        assert(liquidationProtection.MORPHO() == MORPHO);

        assert(liquidationProtection.prelltv() == subscription.prelltv);
        assert(liquidationProtection.closeFactor() == subscription.closeFactor);
        assert(liquidationProtection.preLiquidationIncentive() == subscription.preLiquidationIncentive);

        assert(liquidationProtection.lltv() == market.lltv);
        assert(liquidationProtection.collateralToken() == market.collateralToken);
        assert(liquidationProtection.loanToken() == market.loanToken);
        assert(liquidationProtection.irm() == market.irm);
        assert(liquidationProtection.oracle() == market.oracle);
    }
}
