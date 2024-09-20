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

        assert(preLiquidation.PRE_LLTV() == preLiquidationParams.preLltv);
        assert(preLiquidation.CLOSE_FACTOR() == preLiquidationParams.closeFactor);
        assert(preLiquidation.PRE_LIQUIDATION_INCENTIVE() == preLiquidationParams.preLiquidationIncentive);

        assert(preLiquidation.LLTV() == marketParams.lltv);
        assert(preLiquidation.COLLATERAL_TOKEN() == marketParams.collateralToken);
        assert(preLiquidation.LOAN_TOKEN() == marketParams.loanToken);
        assert(preLiquidation.IRM() == marketParams.irm);
        assert(preLiquidation.ORACLE() == marketParams.oracle);

        bytes32 preLiquidationId = factory.getPreLiquidationId(id, preLiquidationParams);
        assert(factory.preLiquidations(preLiquidationId) == preLiquidation);
    }
}
