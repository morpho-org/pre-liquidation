// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {SubscriptionParams, IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract PreLiquidationFactoryTest is BaseTest {
    PreLiquidationFactory factory;

    function setUp() public override {
        super.setUp();
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new PreLiquidationFactory(address(0));
    }

    function testCreatePreLiquidation(SubscriptionParams memory subscription) public {
        vm.assume(subscription.prelltv < lltv);

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation = factory.createPreLiquidation(market, subscription);

        assert(preLiquidation.MORPHO() == MORPHO);

        assert(preLiquidation.prelltv() == subscription.prelltv);
        assert(preLiquidation.closeFactor() == subscription.closeFactor);
        assert(preLiquidation.preLiquidationIncentive() == subscription.preLiquidationIncentive);

        assert(preLiquidation.lltv() == market.lltv);
        assert(preLiquidation.collateralToken() == market.collateralToken);
        assert(preLiquidation.loanToken() == market.loanToken);
        assert(preLiquidation.irm() == market.irm);
        assert(preLiquidation.oracle() == market.oracle);

        MarketParams memory _market = market;
        bytes32 subscriptionId = getPreLiquidationId(_market, subscription);
        assert(factory.preliquidations(subscriptionId) == preLiquidation);
    }

    function getPreLiquidationId(MarketParams memory marketParams, SubscriptionParams memory subscriptionParams)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(marketParams, subscriptionParams));
    }
}
