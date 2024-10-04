// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {SoftLiquidationAddressLib} from "../src/libraries/periphery/SoftLiquidationAddressLib.sol";

contract SoftLiquidationFactoryTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new SoftLiquidationFactory(address(0));
    }

    function testCreateSoftLiquidation(SoftLiquidationParams memory softLiquidationParams) public {
        softLiquidationParams = boundSoftLiquidationParameters(
            softLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        softLiquidationParams.softLIF2 = softLiquidationParams.softLIF1;
        softLiquidationParams.softLCF2 = softLiquidationParams.softLCF1;

        factory = new SoftLiquidationFactory(address(MORPHO));
        ISoftLiquidation softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        assert(softLiquidation.MORPHO() == MORPHO);
        assert(Id.unwrap(softLiquidation.ID()) == Id.unwrap(id));

        SoftLiquidationParams memory softLiqParams = softLiquidation.softLiquidationParams();
        assert(softLiqParams.softLltv == softLiquidationParams.softLltv);
        assert(softLiqParams.softLCF1 == softLiquidationParams.softLCF1);
        assert(softLiqParams.softLCF2 == softLiquidationParams.softLCF2);
        assert(softLiqParams.softLIF1 == softLiquidationParams.softLIF1);
        assert(softLiqParams.softLIF2 == softLiquidationParams.softLIF2);
        assert(softLiqParams.softLiquidationOracle == softLiquidationParams.softLiquidationOracle);

        MarketParams memory softLiqMarketParams = softLiquidation.marketParams();
        assert(softLiqMarketParams.loanToken == marketParams.loanToken);
        assert(softLiqMarketParams.collateralToken == marketParams.collateralToken);
        assert(softLiqMarketParams.oracle == marketParams.oracle);
        assert(softLiqMarketParams.irm == marketParams.irm);
        assert(softLiqMarketParams.lltv == marketParams.lltv);

        assert(factory.isSoftLiquidation(address(softLiquidation)));
    }

    function testCreate2Deployment(SoftLiquidationParams memory softLiquidationParams) public {
        softLiquidationParams = boundSoftLiquidationParameters(
            softLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        softLiquidationParams.softLIF2 = softLiquidationParams.softLIF1;
        softLiquidationParams.softLCF2 = softLiquidationParams.softLCF1;

        factory = new SoftLiquidationFactory(address(MORPHO));
        ISoftLiquidation softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        address softLiquidationAddress = SoftLiquidationAddressLib.computeSoftLiquidationAddress(
            address(MORPHO), address(factory), id, softLiquidationParams
        );
        assert(address(softLiquidation) == softLiquidationAddress);
    }

    function testRedundantSoftLiquidation(SoftLiquidationParams memory softLiquidationParams) public {
        softLiquidationParams = boundSoftLiquidationParameters(
            softLiquidationParams,
            WAD / 100,
            marketParams.lltv - 1,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        softLiquidationParams.softLIF2 = softLiquidationParams.softLIF1;
        softLiquidationParams.softLCF2 = softLiquidationParams.softLCF1;

        factory = new SoftLiquidationFactory(address(MORPHO));

        factory.createSoftLiquidation(id, softLiquidationParams);

        vm.expectRevert(bytes(""));
        factory.createSoftLiquidation(id, softLiquidationParams);
    }
}
