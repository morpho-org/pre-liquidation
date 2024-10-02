// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "./BaseTest.sol";

import {IPreLiquidation} from "../src/interfaces/IPreLiquidation.sol";
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

    function testHighPreLltv(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
        (preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle) = boundPreLiquidationParameters(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            marketParams.lltv,
            type(uint256).max,
            WAD / 100,
            WAD,
            WAD,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PreLltvTooHigh.selector));
        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);
    }

    function testCloseFactorDecreasing(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
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
            WAD + 1,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1 - 1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.CloseFactorDecreasing.selector));
        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);
    }

    function testLowPreLIF(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
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
            0,
            WAD - 1,
            marketParams.oracle
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.preLIFTooLow.selector));
        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);
    }

    function testpreLIFDecreasing(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
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
            WAD + 1,
            WAD.wDivDown(lltv),
            marketParams.oracle
        );
        preLIF2 = preLIF1 - 1;
        preCF2 = preCF1;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.preLIFDecreasing.selector));
        factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);
    }

    function testNonexistentMarket(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NonexistentMarket.selector));
        factory.createPreLiquidation(
            Id.wrap(bytes32(0)), preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle
        );
    }

    function testInconsistentInput(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 seizedAssets,
        uint256 repaidShares
    ) public virtual {
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

        preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        seizedAssets = bound(seizedAssets, 1, type(uint256).max);
        repaidShares = bound(repaidShares, 1, type(uint256).max);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, seizedAssets, repaidShares, hex"");
    }

    function testEmptyPreLiquidation(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
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

        preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        vm.expectRevert(ErrorsLib.InconsistentInput.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 0, hex"");
    }

    function testNotMorpho(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) public virtual {
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

        preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

        vm.expectRevert(ErrorsLib.NotMorpho.selector);
        IMorphoRepayCallback(address(preLiquidation)).onMorphoRepay(0, hex"");
    }

    function preparePreLiquidation(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address liquidator
    ) public {
        preLiquidation =
            factory.createPreLiquidation(id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle);

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

    function testNotPreLiquidatable(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount
    ) public virtual {
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

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        preparePreLiquidation(
            preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle, collateralAmount, 0, LIQUIDATOR
        );

        vm.expectRevert(ErrorsLib.NotPreLiquidatablePosition.selector);
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");
    }

    function testPreLiquidation(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
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

        collateralAmount = bound(collateralAmount, 10 ** 19, 10 ** 24);
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowLiquidationThreshold = collateralAmount.mulDivDown(
            IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE
        ).wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLltv);
        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        preparePreLiquidation(
            preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle, collateralAmount, borrowAmount, LIQUIDATOR
        );

        vm.startPrank(LIQUIDATOR);
        Position memory position = MORPHO.position(id, BORROWER);
        Market memory m = MORPHO.market(id);

        uint256 ltv = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares).wDivDown(
            uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
        );
        uint256 preLIF = (ltv - preLltv).wMulDown(preLIF2 - preLIF1).wDivDown(marketParams.lltv - preLltv) + preLIF1;

        uint256 closeFactor = (ltv - preLltv).wMulDown(preCF2 - preCF1).wDivDown(marketParams.lltv - preLltv) + preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            preLIF
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }

    function testPreLiquidationCallback(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public virtual {
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

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowLiquidationThreshold = collateralAmount.mulDivDown(
            IOracle(marketParams.oracle).price(), ORACLE_PRICE_SCALE
        ).wMulDown(marketParams.lltv);
        uint256 borrowPreLiquidationThreshold =
            collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLltv);

        borrowAmount = bound(borrowAmount, borrowPreLiquidationThreshold + 1, borrowLiquidationThreshold);

        preparePreLiquidation(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            preLiquidationOracle,
            collateralAmount,
            borrowAmount,
            address(this)
        );

        Position memory position = MORPHO.position(marketParams.id(), BORROWER);
        Market memory m = MORPHO.market(marketParams.id());

        uint256 ltv = uint256(position.borrowShares).toAssetsUp(m.totalBorrowAssets, m.totalBorrowShares).wDivDown(
            uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
        );
        uint256 preLIF = (ltv - preLltv).wMulDown(preLIF2 - preLIF1).wDivDown(marketParams.lltv - preLltv) + preLIF1;

        uint256 closeFactor = (ltv - preLltv).wMulDown(preCF2 - preCF1).wDivDown(marketParams.lltv - preLltv) + preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            preLIF
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

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

    function testPreLiquidationWithInterest(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount
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

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowThreshold =
            uint256(collateralAmount).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLltv) - 1;
        preparePreLiquidation(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            preLiquidationOracle,
            collateralAmount,
            borrowThreshold,
            LIQUIDATOR
        );

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
        console.log(ltv, preLltv, marketParams.lltv);
        vm.assume(ltv >= preLltv);
        vm.assume(ltv <= marketParams.lltv);
        uint256 preLIF = (ltv - preLltv).wMulDown(preLIF2 - preLIF1).wDivDown(marketParams.lltv - preLltv) + preLIF1;

        uint256 closeFactor = (ltv - preLltv).wMulDown(preCF2 - preCF1).wDivDown(marketParams.lltv - preLltv) + preCF1;
        uint256 repayableShares = position.borrowShares.wMulDown(closeFactor);
        uint256 seizedAssets = uint256(repayableShares).toAssetsDown(m.totalBorrowAssets, m.totalBorrowShares).wMulDown(
            preLIF
        ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        vm.assume(seizedAssets > 0);

        preLiquidation.preLiquidate(BORROWER, 0, repayableShares, hex"");
    }

    function testOracle(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle,
        uint256 collateralAmount
    ) public virtual {
        OracleMock customOracle = new OracleMock();
        customOracle.setPrice(2 * IOracle(marketParams.oracle).price());

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
            address(customOracle)
        );
        preLIF2 = preLIF1;
        preCF2 = preCF1;

        collateralAmount = bound(collateralAmount, 10 ** 18, 10 ** 24);

        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        uint256 borrowThreshold =
            uint256(collateralAmount).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLltv) - 1;
        preparePreLiquidation(
            preLltv,
            preCF1,
            preCF2,
            preLIF1,
            preLIF2,
            preLiquidationOracle,
            collateralAmount,
            borrowThreshold,
            LIQUIDATOR
        );

        vm.warp(block.timestamp + 12);
        vm.roll(block.number + 1);

        MORPHO.accrueInterest(marketParams);

        vm.startPrank(LIQUIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotPreLiquidatablePosition.selector));
        preLiquidation.preLiquidate(BORROWER, 0, 1, hex"");
    }
}
