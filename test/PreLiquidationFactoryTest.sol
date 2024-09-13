// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {PreLiquidationParams, IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
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

    function testCreatePreLiquidation(PreLiquidationParams memory preLiquidationParams) public {
        vm.assume(preLiquidationParams.prelltv < lltv);

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation = factory.createPreLiquidation(market, preLiquidationParams);

        assert(preLiquidation.MORPHO() == MORPHO);

        assert(preLiquidation.prelltv() == preLiquidationParams.prelltv);
        assert(preLiquidation.closeFactor() == preLiquidationParams.closeFactor);
        assert(preLiquidation.preLiquidationIncentive() == preLiquidationParams.preLiquidationIncentive);

        assert(preLiquidation.lltv() == market.lltv);
        assert(preLiquidation.collateralToken() == market.collateralToken);
        assert(preLiquidation.loanToken() == market.loanToken);
        assert(preLiquidation.irm() == market.irm);
        assert(preLiquidation.oracle() == market.oracle);

        MarketParams memory _market = market;
        bytes32 preLiquidationId = getPreLiquidationId(_market, preLiquidationParams);
        assert(factory.preliquidations(preLiquidationId) == preLiquidation);
    }

    function getPreLiquidationId(MarketParams memory marketParams, PreLiquidationParams memory preLiquidationParams)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(marketParams, preLiquidationParams));
    }
}
