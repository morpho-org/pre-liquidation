// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {PreLiquidationParams, IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract PreLiquidationFactoryTest is BaseTest {
    using MarketParamsLib for MarketParams;

    PreLiquidationFactory factory;

    function setUp() public override {
        super.setUp();
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new PreLiquidationFactory(address(0));
    }

    function testCreatePreLiquidation(PreLiquidationParams memory preLiquidationParams) public {
        vm.assume(preLiquidationParams.preLltv < lltv);

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        assert(preLiquidation.MORPHO() == MORPHO);
        assert(Id.unwrap(preLiquidation.ID()) == Id.unwrap(id));

        PreLiquidationParams memory preLiqParams = preLiquidation.getPreLiquidationParams();
        assert(preLiqParams.preLltv == preLiquidationParams.preLltv);
        assert(preLiqParams.closeFactor == preLiquidationParams.closeFactor);
        assert(preLiqParams.preLiquidationIncentive == preLiquidationParams.preLiquidationIncentive);
        assert(preLiqParams.preLiquidationOracle == preLiquidationParams.preLiquidationOracle);

        MarketParams memory preLiqMarketParams = preLiquidation.getMarketParams();
        assert(preLiqMarketParams.loanToken == marketParams.loanToken);
        assert(preLiqMarketParams.collateralToken == marketParams.collateralToken);
        assert(preLiqMarketParams.oracle == marketParams.oracle);
        assert(preLiqMarketParams.irm == marketParams.irm);
        assert(preLiqMarketParams.lltv == marketParams.lltv);

        bytes32 preLiquidationId = factory.getPreLiquidationId(id, preLiquidationParams);
        assert(factory.preLiquidations(preLiquidationId) == preLiquidation);
    }
}
