// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {SubscriptionParams, ILiquidationProtection} from "../src/interfaces/ILiquidationProtection.sol";
import {LiquidationProtectionFactory} from "../src/LiquidationProtectionFactory.sol";

contract LiquidationProtectionFactoryTest is BaseTest {
    LiquidationProtectionFactory factory;

    function setUp() public override {
        super.setUp();

        factory = new LiquidationProtectionFactory(address(MORPHO));
    }

    function testCreatePreLiquidation(SubscriptionParams calldata subscription) public {
        vm.assume(subscription.prelltv < lltv);

        ILiquidationProtection liquidationProtection = factory.createPreLiquidation(market, subscription);
    }
}
