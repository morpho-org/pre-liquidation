// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";

contract PreLiquidationErrorTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    function setUp() public override {
        super.setUp();

        factory = new PreLiquidationFactory(address(MORPHO));
    }

    function testHighPreLltv(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: marketParams.lltv,
            maxPreLltv: type(uint256).max,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
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
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD + 1,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });
        preLiquidationParams.preLCF2 = bound(preLiquidationParams.preLCF2, 0, preLiquidationParams.preLCF1 - 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLCFDecreasing.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testLowPreLIF(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: 0,
            maxPreLIF: WAD - 1,
            preLiqOracle: marketParams.oracle
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLIFTooLow.selector));
        factory.createPreLiquidation(id, preLiquidationParams);
    }

    function testpreLIFDecreasing(PreLiquidationParams memory preLiquidationParams) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD + 1,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        preLiquidationParams.preLIF2 = bound(preLiquidationParams.preLIF2, WAD, preLiquidationParams.preLIF1 - 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLIFDecreasing.selector));
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
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
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
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
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
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        vm.expectRevert(ErrorsLib.NotMorpho.selector);
        IMorphoRepayCallback(address(preLiquidation)).onMorphoRepay(0, hex"");
    }

    function testNotPreLiquidatable(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        (uint256 collateralQuoted,,) = _getBorrowBounds(preLiquidationParams, marketParams, collateralAmount);

        borrowAmount = bound(borrowAmount, 0, collateralQuoted.wMulDown(preLiquidationParams.preLltv));

        _preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        Position memory position = MORPHO.position(id, BORROWER);

        vm.assume(position.borrowShares > 0);

        vm.expectRevert(ErrorsLib.NotPreLiquidatablePosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, position.borrowShares, hex"");
    }

    function testPreLiquidationTooLargeWithShares(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 repaidShares
    ) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowPreLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(preLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        _preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        uint256 closeFactor = _closeFactor(preLiquidationParams, ltv);
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);

        repaidShares = bound(repaidShares, repayableShares + 1, type(uint128).max);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.PreLiquidationTooLarge.selector, repaidShares, repayableShares)
        );
        preLiquidation.preLiquidate(BORROWER, 0, repaidShares, hex"");
    }

    function testPreLiquidationTooLargeWithAssets(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 seizedAssets
    ) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowPreLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(preLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        _preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory market = MORPHO.market(id);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);

        uint256 closeFactor = _closeFactor(preLiquidationParams, ltv);
        uint256 preLIF = _preLIF(preLiquidationParams, ltv);
        uint256 collateralPrice = IOracle(preLiquidationParams.preLiquidationOracle).price();

        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);
        uint256 upperSeizedAssetBound = (repayableShares + 1).toAssetsUp(
            market.totalBorrowAssets, market.totalBorrowShares
        ).mulDivUp(preLIF, WAD).mulDivUp(ORACLE_PRICE_SCALE, collateralPrice);

        seizedAssets = bound(seizedAssets, upperSeizedAssetBound, type(uint128).max);

        uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);
        uint256 repaidShares =
            seizedAssetsQuoted.wDivUp(preLIF).toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        vm.assume(repaidShares > repayableShares);

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.PreLiquidationTooLarge.selector, repaidShares, repayableShares)
        );
        preLiquidation.preLiquidate(BORROWER, seizedAssets, 0, hex"");
    }

    function testPreLiquidationUndercollateralizedPosition(PreLiquidationParams memory preLiquidationParams, uint256 collateralAmount, uint256 oraclePrice, uint256 repaidShares) public virtual {
        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minPreLCF: WAD / 100,
            maxPreLCF: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: marketParams.oracle
        });

        oraclePrice = bound(oraclePrice, 1, ORACLE_PRICE_SCALE / 2);
        OracleMock(preLiquidationParams.preLiquidationOracle).setPrice(oraclePrice);

        uint256 collateralPrice = IOracle(preLiquidationParams.preLiquidationOracle).price();

        collateralAmount = bound(collateralAmount, 1, ORACLE_PRICE_SCALE / collateralPrice - 1);

        _preparePreLiquidation(preLiquidationParams, collateralAmount, 0, LIQUIDATOR);

        repaidShares = bound(repaidShares, 1, type(uint128).max);

        vm.expectRevert(ErrorsLib.UncollateralizedPosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, repaidShares, hex"");
    }
}
