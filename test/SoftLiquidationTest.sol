// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {ISoftLiquidation, SoftLiquidationParams} from "../src/interfaces/ISoftLiquidation.sol";
import {ISoftLiquidationCallback} from "../src/interfaces/ISoftLiquidationCallback.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import {SoftLiquidation} from "../src/SoftLiquidation.sol";
import {SoftLiquidationFactory} from "../src/SoftLiquidationFactory.sol";
import "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

contract SoftLiquidationTest is BaseTest, ISoftLiquidationCallback {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    event CallbackReached();

    function setUp() public override {
        super.setUp();

        factory = new SoftLiquidationFactory(address(MORPHO));
    }

    function testSoftLiquidationShares(
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

        uint256 liquidatorCollatBefore = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanBefore = loanToken.balanceOf(LIQUIDATOR);

        (uint256 seizedAssets, uint256 repaidAssets) = softLiquidation.softLiquidate(BORROWER, 0, repayableShares, hex"");

        uint256 liquidatorCollatAfter = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanAfter = loanToken.balanceOf(LIQUIDATOR);

        assertEq(liquidatorCollatAfter - liquidatorCollatBefore, seizedAssets);
        assertEq(liquidatorLoanBefore - liquidatorLoanAfter, repaidAssets);
    }

    function testSoftLiquidationAssets(
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

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowSoftLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowSoftLiquidationThreshold + 1, borrowLiquidationThreshold);
        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        uint256 closeFactor = _closeFactor(softLiquidationParams, ltv);
        uint256 softLIF = _softLIF(softLiquidationParams, ltv);

        uint256 collateralPrice = IOracle(softLiquidationParams.softLiquidationOracle).price();
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);
        uint256 seizabledAssets = repayableShares.toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            softLIF
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);

        uint256 liquidatorCollatBefore = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanBefore = loanToken.balanceOf(LIQUIDATOR);

        (uint256 seizedAssets, uint256 repaidAssets) = softLiquidation.softLiquidate(BORROWER, seizabledAssets, 0, hex"");

        uint256 liquidatorCollatAfter = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanAfter = loanToken.balanceOf(LIQUIDATOR);

        assertEq(liquidatorCollatAfter - liquidatorCollatBefore, seizedAssets);
        assertEq(liquidatorLoanBefore - liquidatorLoanAfter, repaidAssets);
    }

    function testSoftLiquidationCallback(
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

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);
        (uint256 collateralQuoted, uint256 borrowSoftLiquidationThreshold, uint256 borrowLiquidationThreshold) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);
        borrowAmount = bound(borrowAmount, borrowSoftLiquidationThreshold + 1, borrowLiquidationThreshold);

        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, address(this));

        Position memory position = MORPHO.position(marketParams.id(), BORROWER);

        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        uint256 closeFactor = _closeFactor(softLiquidationParams, ltv);
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);

        bytes memory data = abi.encode(this.testSoftLiquidationCallback.selector, hex"");

        vm.recordLogs();
        softLiquidation.softLiquidate(BORROWER, 0, repayableShares, data);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assert(entries.length == 7);
        assert(entries[3].topics[0] == keccak256("CallbackReached()"));
    }

    function onSoftLiquidate(uint256, bytes memory data) external {
        bytes4 selector;
        (selector,) = abi.decode(data, (bytes4, bytes));
        require(selector == this.testSoftLiquidationCallback.selector);

        emit CallbackReached();
    }

    function testSoftLiquidationWithInterest(SoftLiquidationParams memory softLiquidationParams, uint256 collateralAmount)
        public
    {
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

        (uint256 collateralQuoted, uint256 borrowSoftLiquidationThreshold,) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);
        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowSoftLiquidationThreshold - 1, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotSoftLiquidatablePosition.selector));
        softLiquidation.softLiquidate(BORROWER, 0, 1, hex"");

        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);

        MORPHO.accrueInterest(marketParams);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 borrowAmount = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares);
        uint256 ltv = borrowAmount.wDivUp(collateralQuoted);
        vm.assume(ltv >= softLiquidationParams.softLltv);
        vm.assume(ltv <= marketParams.lltv);

        uint256 closeFactor = _closeFactor(softLiquidationParams, ltv);
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(closeFactor);

        softLiquidation.softLiquidate(BORROWER, 0, repayableShares, hex"");
    }

    function testOracle(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
        OracleMock customOracle = new OracleMock();
        customOracle.setPrice(2 * IOracle(marketParams.oracle).price());

        softLiquidationParams = boundSoftLiquidationParameters({
            softLiquidationParams: softLiquidationParams,
            minSoftLltv: WAD / 100,
            maxSoftLltv: marketParams.lltv - 1,
            minSoftLCF: WAD / 100,
            maxSoftLCF: WAD,
            minSoftLIF: WAD,
            maxSoftLIF: WAD.wDivDown(lltv),
            softLiqOracle: address(customOracle)
        });

        collateralAmount = bound(collateralAmount, minCollateral, maxCollateral);

        uint256 collateralMarketOraclePrice = IOracle(marketParams.oracle).price();
        uint256 borrowMarketOracleThreshold = uint256(collateralAmount).mulDivDown(
            collateralMarketOraclePrice, ORACLE_PRICE_SCALE
        ).wMulDown(softLiquidationParams.softLltv);
        (, uint256 borrowSoftLiquidationThreshold,) =
            _getBorrowBounds(softLiquidationParams, marketParams, collateralAmount);

        uint256 maxBorrow = uint256(collateralAmount).mulDivDown(collateralMarketOraclePrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);
        borrowAmount = bound(borrowAmount, borrowMarketOracleThreshold, borrowSoftLiquidationThreshold - 1);
        borrowAmount = bound(borrowAmount, borrowMarketOracleThreshold, maxBorrow - 1);

        _prepareSoftLiquidation(softLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotSoftLiquidatablePosition.selector));
        softLiquidation.softLiquidate(BORROWER, 0, 1, hex"");
    }
}
