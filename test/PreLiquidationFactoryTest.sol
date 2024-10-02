// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {PreLiquidationAddressLib} from "../src/libraries/periphery/PreLiquidationAddressLib.sol";
import {WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";

contract PreLiquidationFactoryTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;

    PreLiquidationFactory factory;

    function setUp() public override {
        super.setUp();
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new PreLiquidationFactory(address(0));
    }

    function testCreatePreLiquidation(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public {
        (preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle) = boundPreLiquidationParameters(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        factory = new PreLiquidationFactory(address(MORPHO));
        IPreLiquidation preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        assert(preLiquidation.MORPHO() == MORPHO);
        assert(Id.unwrap(preLiquidation.ID()) == Id.unwrap(id));

        (
            uint256 _preLltv,
            uint256 _preCF1,
            uint256 _preCF2,
            uint256 _preLIF1,
            uint256 _preLIF2,
            address _preLiquidationOracle
        ) = preLiquidation.preLiquidationParams();
        assert(_preLltv == preLltv);
        assert(_preCF1 == preCF1);
        assert(_preCF2 == preCF2);
        assert(_preLIF1 == preLIF1);
        assert(_preLIF2 == preLIF2);
        assert(_preLiquidationOracle == preLiquidationOracle);

        MarketParams memory preLiqMarketParams = preLiquidation.marketParams();
        assert(preLiqMarketParams.loanToken == marketParams.loanToken);
        assert(preLiqMarketParams.collateralToken == marketParams.collateralToken);
        assert(preLiqMarketParams.oracle == marketParams.oracle);
        assert(preLiqMarketParams.irm == marketParams.irm);
        assert(preLiqMarketParams.lltv == marketParams.lltv);

        assert(factory.isPreLiquidation(address(preLiquidation)));
    }

    function testCreate2Deployment(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public {
        (preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle) = boundPreLiquidationParameters(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        factory = new PreLiquidationFactory(address(MORPHO));
        console.log("PRE LIF 1", preLIF1);
        IPreLiquidation preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        address preLiquidationAddress = PreLiquidationAddressLib.computePreLiquidationAddress(
            address(MORPHO), address(factory), id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle
        );
        assertEq(address(preLiquidation), preLiquidationAddress);
    }

    function testRedundantPreLiquidation(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public {
        (preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle) = boundPreLiquidationParameters(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        factory = new PreLiquidationFactory(address(MORPHO));

        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        vm.expectRevert(bytes(""));
        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);
    }
}
