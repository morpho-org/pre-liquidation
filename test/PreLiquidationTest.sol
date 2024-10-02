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

contract PreLiquidationTest is BaseTest, IPreLiquidationCallback {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    PreLiquidationFactory internal factory;
    IPreLiquidation internal preLiquidation;

    event CallbackReached();

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

    function preparePreLiquidation(
        PreLiquidationParams memory preLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address liquidator
    ) public {
        preLiquidation = factory.createPreLiquidation(id, preLiquidationParams);

        loanToken.mint(SUPPLIER, borrowAmount);
        vm.prank(SUPPLIER);
        if (borrowAmount > 0) {
            MORPHO.supply(marketParams, borrowAmount, 0, SUPPLIER, hex"");
        }

        collateralToken.mint(BORROWER, collateralAmount);
        vm.startPrank(BORROWER);
        MORPHO.supplyCollateral(marketParams, collateralAmount, BORROWER, hex"");

        vm.startPrank(liquidator);
        loanToken.mint(liquidator, type(uint128).max);
        loanToken.approve(address(preLiquidation), type(uint256).max);

        vm.startPrank(BORROWER);
        if (borrowAmount > 0) {
            MORPHO.borrow(marketParams, borrowAmount, 0, BORROWER, BORROWER);
        }
        MORPHO.setAuthorization(address(preLiquidation), true);
        vm.stopPrank();
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

        preparePreLiquidation(preLiquidationParams, collateralAmount, 0, LIQUIDATOR);

        vm.expectRevert(ErrorsLib.NotPreLiquidatablePosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");
    }

    function testPreLiquidation(
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
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowLiquidationThreshold = collateralAmount.mulDivDown(
            IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE
        ).wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLiquidationParams.preLltv);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 ltv = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares).wDivDown(
            uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
        );

        uint256 closeFactor = (ltv - preLiquidationParams.preLltv).wMulDown(
            preLiquidationParams.preCF2 - preLiquidationParams.preCF1
        ).wDivDown(marketParams.lltv - preLiquidationParams.preLltv) + preLiquidationParams.preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);

        uint256 liquidatorCollatBefore = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanBefore = loanToken.balanceOf(LIQUIDATOR);

        (uint256 seizedAssets, uint256 repaidAssets) = preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");

        uint256 liquidatorCollatAfter = collateralToken.balanceOf(LIQUIDATOR);
        uint256 liquidatorLoanAfter = loanToken.balanceOf(LIQUIDATOR);

        assertEq (liquidatorCollatAfter - liquidatorCollatBefore, seizedAssets);
        assertEq (liquidatorLoanBefore - liquidatorLoanAfter, repaidAssets);
    }

    function testPreLiquidationCallback(
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

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowLiquidationThreshold = collateralAmount.mulDivDown(
            IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE
        ).wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLiquidationParams.preLltv);

        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        preparePreLiquidation(preLiquidationParams, collateralAmount, borrowAmount, address(this));

        Position memory position = MORPHO.position(marketParams.id(), BORROWER);
        Market memory m = MORPHO.market(marketParams.id());

        uint256 ltv = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares).wDivDown(
            uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
        );

        uint256 closeFactor = (ltv - preLiquidationParams.preLltv).wMulDown(
            preLiquidationParams.preCF2 - preLiquidationParams.preCF1
        ).wDivDown(marketParams.lltv - preLiquidationParams.preLltv) + preLiquidationParams.preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);

        bytes memory data = abi.encode(this.testPreLiquidationCallback.selector, hex"");

        vm.recordLogs();
        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, data);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assert(entries.length == 7);
        assert(entries[3].topics[0] == keccak256("CallbackReached()"));
    }

    function onPreLiquidate(uint256, bytes memory data) external {
        bytes4 selector;
        (selector,) = abi.decode(data, (bytes4, bytes));
        require(selector == this.testPreLiquidationCallback.selector);

        emit CallbackReached();
    }

    function testPreLiquidationWithInterest(PreLiquidationParams memory preLiquidationParams, uint256 collateralAmount)
        public
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

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowThreshold = uint256(collateralAmount).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(
            preLiquidationParams.preLltv
        ) - 1;
        preparePreLiquidation(preLiquidationParams, collateralAmount, borrowThreshold, LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotPreLiquidatablePosition.selector));
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");

        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);

        MORPHO.accrueInterest(marketParams);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 ltv = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares).wDivDown(
            uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
        );
        console.log(ltv, preLiquidationParams.preLltv, marketParams.lltv);
        vm.assume(ltv >= preLiquidationParams.preLltv);
        vm.assume(ltv <= marketParams.lltv);

        uint256 closeFactor = (ltv - preLiquidationParams.preLltv).wMulDown(
            preLiquidationParams.preCF2 - preLiquidationParams.preCF1
        ).wDivDown(marketParams.lltv - preLiquidationParams.preLltv) + preLiquidationParams.preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }

    function testOracle(PreLiquidationParams memory preLiquidationParams, uint256 collateralAmount) public virtual {
        OracleMock customOracle = new OracleMock();
        customOracle.setPrice(2 * IOracle(marketParams.oracle).price());

        preLiquidationParams = boundPreLiquidationParameters({
            preLiquidationParams: preLiquidationParams,
            minPreLltv: WAD / 100,
            maxPreLltv: marketParams.lltv - 1,
            minCloseFactor: WAD / 100,
            maxCloseFactor: WAD,
            minPreLIF: WAD,
            maxPreLIF: WAD.wDivDown(lltv),
            preLiqOracle: address(customOracle)
        });

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowThreshold = uint256(collateralAmount).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(
            preLiquidationParams.preLltv
        ) - 1;
        preparePreLiquidation(preLiquidationParams, collateralAmount, borrowThreshold, LIQUIDATOR);

        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);

        MORPHO.accrueInterest(marketParams);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotPreLiquidatablePosition.selector));
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");
    }
}
