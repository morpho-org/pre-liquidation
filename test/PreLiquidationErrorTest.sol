// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {IPreLiquidation, PreLiquidationParams} from "../src/interfaces/IPreLiquidation.sol";
import {IPreLiquidationCallback} from "../src/interfaces/IPreLiquidationCallback.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import {PreLiquidation} from "../src/PreLiquidation.sol";
import {PreLiquidationFactory} from "../src/PreLiquidationFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";

contract PreLiquidationErrorTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    function setUp() public override {
        super.setUp();

        factory = new PreLiquidationFactory(address(MORPHO));
    }

    function testHighPreLltv(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: marketParams.lltv,
            maxPreLltv: type(uint256).max,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLltvTooHigh.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testCloseFactorDecreasing(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD + 1,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });
        preLiquidationParams.preCF2 = preLiquidationParams.preCF1 - 1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.CloseFactorDecreasing.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testLowPreLIF(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: 0,
            maxPreLIF: WAD - 1,
            preLiqOracle: marketParams.oracle
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.preLIFTooLow.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testpreLIFDecreasing(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD + 1,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });
        preLiquidationParams.preLIF2 = preLiquidationParams.preLIF1 - 1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.preLIFDecreasing.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testNonexistentMarket(PreLiquidationParams memory preLiquidationParams) public virtual {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NonexistentMarket.selector));
        factory.createPreLiquidation(Id.wrap(bytes32(0)), preLiquidationParams);
    }

    function testInconsistentInput(
        PreLiquidationParams memory preLiquidationParams,
        uint256 seizedAssets,
        uint256 repaidShares
    ) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        seizedAssets = bound(seizedAssets, 1, type(uint256).max);
        repaidShares = bound(repaidShares, 1, type(uint256).max);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, seizedAssets, repaidShares, hex"");
    }

    function testEmptyPreLiquidation(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 0, hex"");
    }

    function testNotMorpho(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        vm.expectRevert(ErrorsLib.NotMorpho.selector);
        IMorphoRepayCallback(address(preLiquidation)).onMorphoRepay(0, hex"");
    }

    function testNotPreLiquidatable(PreLiquidationParams memory preLiquidationParams, uint256 collateralAmount)
        public
        virtual
    {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        _preparePreLiquidation(preLiquidationParams, collateralAmount, 0, LIQUIDATOR);

        vm.expectRevert(ErrorsLib.NotPreLiquidatablePosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");
    }

    function testPreLiquidationTooLarge(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, 10 ** 19, 10 ** 24);
        uint256 collateralPrice = IOracle(preLiquidationParams.preLiquidationOracle).price();
        uint256 collateralQuoted = collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE);
        uint256 borrowLiquidationThreshold = collateralQuoted.wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold = collateralQuoted.wMulDown(preLiquidationParams.preLltv);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        _preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        uint256 closeFactor = _closeFactor(preLiquidationParams, ltv);
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.PreLiquidationTooLarge.selector, repayableShares + 1, repayableShares)
        );
        preLiquidation.preLiquidate(BORROWER, 0, repayableShares + 1, hex"");
    }
}
