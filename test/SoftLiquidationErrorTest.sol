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

contract SoftLiquidationErrorTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    function setUp() public override {
        super.setUp();

        factory = new SoftLiquidationFactory(address(MORPHO));
    }

    function testHighSoftLltv(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: marketParams.lltv,
            maxSoftLltv: type(uint256).max,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SoftLltvTooHigh.selector));
        factory.createSoftLiquidation(id, softLiquidationParams);
    }

    function testCloseFactorDecreasing(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD + 1,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });
        softLiquidationParams.softLCF2 = bound(softLiquidationParams.softLCF2, 0, softLiquidationParams.softLCF1 - 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SoftLCFDecreasing.selector));
        factory.createSoftLiquidation(id, softLiquidationParams);
    }

    function testLowSoftLIF(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: 0,
            maxSoftLIF: WAD - 1,
            softLiqOracle: marketParams.oracle
        });

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SoftLIFTooLow.selector));
        factory.createSoftLiquidation(id, softLiquidationParams);
    }

    function testsoftLIFDecreasing(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD + 1,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        softLiquidationParams.softLIF2 = bound(softLiquidationParams.softLIF2, WAD, softLiquidationParams.softLIF1 - 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SoftLIFDecreasing.selector));
        factory.createSoftLiquidation(id, softLiquidationParams);
    }

    function testNonexistentMarket(SoftLiquidationParams memory softLiquidationParams) public virtual {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NonexistentMarket.selector));
        factory.createSoftLiquidation(Id.wrap(bytes32(0)), softLiquidationParams);
    }

    function testInconsistentInput(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 seizedAssets,
        uint256 repaidShares
    ) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        seizedAssets = bound(seizedAssets, 1, type(uint256).max);
        repaidShares = bound(repaidShares, 1, type(uint256).max);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        softLiquidation.softLiquidate(BORROWER, seizedAssets, repaidShares, hex"");
    }

    function testEmptySoftLiquidation(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        softLiquidation.softLiquidate(BORROWER, 0, 0, hex"");
    }

    function testNotMorpho(SoftLiquidationParams memory softLiquidationParams) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        vm.expectRevert(ErrorsLib.NotMorpho.selector);
        IMorphoRepayCallback(address(softLiquidation)).onMorphoRepay(0, hex"");
    }

    function testNotSoftLiquidatable(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        (uint256 collateralQuoted,,) = _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);

        borrowAmount = bound(borrowAmount, 0, collateralQuoted.wMulDown(softLiquidationParams.softLltv));

        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        Position memory position = MORPHO.position(id, BORROWER);

        vm.assume(position.borrowShares > 0);

        vm.expectRevert(ErrorsLib.NotSoftLiquidatablePosition.selector);
        softLiquidation.softLiquidate(BORROWER, 0, position.borrowShares, hex"");
    }

    function testSoftLiquidationTooLargeWithShares(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 repaidShares
    ) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowSoftLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowSoftLiquidationThreshold + 1, borrowLiquidationThreshold);

        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        uint256 closeFactor = _closeFactor(softLiquidationParams, ltv);
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);

        repaidShares = bound(repaidShares, repayableShares + 1, type(uint128).max);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.SoftLiquidationTooLarge.selector, repaidShares, repayableShares)
        );
        softLiquidation.softLiquidate(BORROWER, 0, repaidShares, hex"");
    }

    function testSoftLiquidationTooLargeWithAssets(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 seizedAssets
    ) public virtual {
        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: marketParams.oracle
        });

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowSoftLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowSoftLiquidationThreshold + 1, borrowLiquidationThreshold);

        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory market = MORPHO.market(id);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);

        uint256 closeFactor = _closeFactor(softLiquidationParams, ltv);
        uint256 softLIF = _softLIF(softLiquidationParams, ltv);
        uint256 collateralPrice = IOracle(softLiquidationParams.softLiquidationOracle).price();

        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);
        uint256 upperSeizedAssetBound = (repayableShares + 1).toAssetsUp(
            market.totalBorrowAssets, market.totalBorrowShares
        ).mulDivUp(softLIF, WAD).mulDivUp(ORACLE_PRICE_SCALE, collateralPrice);

        seizedAssets = bound(seizedAssets, upperSeizedAssetBound, type(uint128).max);

        uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);
        uint256 repaidShares =
            seizedAssetsQuoted.wDivUp(softLIF).toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        vm.assume(repaidShares > repayableShares);

        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.SoftLiquidationTooLarge.selector, repaidShares, repayableShares)
        );
        softLiquidation.softLiquidate(BORROWER, seizedAssets, 0, hex"");
    }
}
