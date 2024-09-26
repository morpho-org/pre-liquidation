// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {PreLiquidationParams, IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {PreLiquidationAddressLib} from "../src/libraries/periphery/PreLiquidationAddressLib.sol";
import {WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";

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
        preLiquidationParams = boundPreLiquidationParameters(
            preLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD + WAD / 10,
            marketParams.oracle
        );
        preLiquidationParams.preLIF2 = preLiquidationParams.preLIF1;

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        assert(preLiquidation.MORPHO() == MORPHO);
        assert(Id.unwrap(preLiquidation.ID()) == Id.unwrap(id));

        PreLiquidationParams memory preLiqParams = preLiquidation.preLiquidationParams();
        assert(preLiqParams.preLltv == preLiquidationParams.preLltv);
        assert(preLiqParams.closeFactor == preLiquidationParams.closeFactor);
        assert(preLiqParams.preLIF1 == preLiquidationParams.preLIF1);
        assert(preLiqParams.preLIF2 == preLiquidationParams.preLIF2);
        assert(preLiqParams.preLiquidationOracle == preLiquidationParams.preLiquidationOracle);

        MarketParams memory preLiqMarketParams = preLiquidation.marketParams();
        assert(preLiqMarketParams.loanToken == marketParams.loanToken);
        assert(preLiqMarketParams.collateralToken == marketParams.collateralToken);
        assert(preLiqMarketParams.oracle == marketParams.oracle);
        assert(preLiqMarketParams.irm == marketParams.irm);
        assert(preLiqMarketParams.lltv == marketParams.lltv);
    }

    function testCreate2Deployment(PreLiquidationParams memory preLiquidationParams) public {
        preLiquidationParams = boundPreLiquidationParameters(
            preLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD + WAD / 10,
            marketParams.oracle
        );
        preLiquidationParams.preLIF2 = preLiquidationParams.preLIF1;

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        address preLiquidationAddress = PreLiquidationAddressLib.computePreLiquidationAddress(
            address(MORPHO), address(factory), id, preLiquidationParams
        );
        assert(address(preLiquidation) == preLiquidationAddress);
    }

    function testRedundantPreLiquidation(PreLiquidationParams memory preLiquidationParams) public {
        preLiquidationParams = boundPreLiquidationParameters(
            preLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD + WAD / 10,
            marketParams.oracle
        );
        preLiquidationParams.preLIF2 = preLiquidationParams.preLIF1;

        factory = new PreLiquidationFactory(address(MORPHO));

        factory.createPreLiquidation(id, preLiquidationParams);

        vm.expectRevert(bytes(""));
        factory.createPreLiquidation(id, preLiquidationParams);
    }
}
