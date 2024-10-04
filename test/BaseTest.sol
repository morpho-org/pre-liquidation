// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IrmMock} from "../src/mocks/IrmMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";

import {MarketParams, IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {ORACLE_PRICE_SCALE} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";

import {SoftLiquidationParams, ISoftLiquidation} from "../src/interfaces/ISoftLiquidation.sol";
import {SoftLiquidationFactory} from "../src/SoftLiquidationFactory.sol";

contract BaseTest is Test {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;

    address internal SUPPLIER = makeAddr("Supplier");
    address internal BORROWER = makeAddr("Borrower");
    address internal LIQUIDATOR = makeAddr("Liquidator");
    address internal MORPHO_OWNER = makeAddr("MorphoOwner");
    address internal MORPHO_FEE_RECIPIENT = makeAddr("MorphoFeeRecipient");

    IMorpho internal MORPHO = IMorpho(deployCode("Morpho.sol", abi.encode(MORPHO_OWNER)));
    ERC20Mock internal loanToken = new ERC20Mock("loan", "B", 18);
    ERC20Mock internal collateralToken = new ERC20Mock("collateral", "C", 18);
    OracleMock internal oracle = new OracleMock();
    IrmMock internal irm = new IrmMock();
    uint256 internal lltv = 0.8 ether; // 80%

    MarketParams internal marketParams;
    Id internal id;

    uint256 internal minCollateral = 10 ** 18;
    uint256 internal maxCollateral = 10 ** 24;

    SoftLiquidationFactory internal factory;
    ISoftLiquidation internal softLiquidation;

    function setUp() public virtual {
        vm.label(address(MORPHO), "Morpho");
        vm.label(address(loanToken), "Loan");
        vm.label(address(collateralToken), "Collateral");
        vm.label(address(oracle), "Oracle");
        vm.label(address(irm), "Irm");

        oracle.setPrice(ORACLE_PRICE_SCALE);

        irm.setApr(0.5 ether); // 50%.

        vm.startPrank(MORPHO_OWNER);
        MORPHO.enableIrm(address(irm));
        MORPHO.setFeeRecipient(MORPHO_FEE_RECIPIENT);

        MORPHO.enableLltv(lltv);
        vm.stopPrank();

        marketParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(oracle),
            irm: address(irm),
            lltv: lltv
        });
        id = marketParams.id();

        MORPHO.createMarket(marketParams);

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(MORPHO), type(uint256).max);
        vm.stopPrank();

        vm.prank(BORROWER);
        collateralToken.approve(address(MORPHO), type(uint256).max);
    }

    function boundSoftLiquidationParameters(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 minSoftLltv,
        uint256 maxSoftLltv,
        uint256 minSoftLCF,
        uint256 maxSoftLCF,
        uint256 minSoftLIF,
        uint256 maxSoftLIF,
        address softLiqOracle
    ) internal pure returns (SoftLiquidationParams memory) {
        softLiquidationParams.softLltv = bound(softLiquidationParams.softLltv, minSoftLltv, maxSoftLltv);
        softLiquidationParams.softLCF1 = bound(softLiquidationParams.softLCF1, minSoftLCF, maxSoftLCF);
        softLiquidationParams.softLCF2 = bound(softLiquidationParams.softLCF2, softLiquidationParams.softLCF1, maxSoftLCF);
        softLiquidationParams.softLIF1 = bound(softLiquidationParams.softLIF1, minSoftLIF, maxSoftLIF);
        softLiquidationParams.softLIF2 = bound(softLiquidationParams.softLIF2, softLiquidationParams.softLIF1, maxSoftLIF);
        softLiquidationParams.softLiquidationOracle = softLiqOracle;

        return softLiquidationParams;
    }

    function _prepareSoftLiquidation(
        SoftLiquidationParams memory softLiquidationParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address liquidator
    ) internal {
        softLiquidation = factory.createSoftLiquidation(id, softLiquidationParams);

        loanToken.mint(SUPPLIER, borrowAmount);
        vm.prank(SUPPLIER);
        if (borrowAmount > 0) {
            MORPHO.supply(marketParams, borrowAmount, 0, SUPPLIER, hex"");
        }

        collateralToken.mint(BORROWER, collateralAmount);
        vm.startPrank(BORROWER);

        MORPHO.supplyCollateral(marketParams, collateralAmount, BORROWER, hex"");

        if (borrowAmount > 0) {
            MORPHO.borrow(marketParams, borrowAmount, 0, BORROWER, BORROWER);
        }
        MORPHO.setAuthorization(address(softLiquidation), true);
        vm.stopPrank();

        loanToken.mint(liquidator, type(uint128).max);
        vm.prank(liquidator);
        loanToken.approve(address(softLiquidation), type(uint256).max);
    }

    function _closeFactor(SoftLiquidationParams memory softLiquidationParams, uint256 ltv)
        internal
        view
        returns (uint256)
    {
        return UtilsLib.min(
            (ltv - softLiquidationParams.softLltv).wDivDown(marketParams.lltv - softLiquidationParams.softLltv).wMulDown(
                softLiquidationParams.softLCF2 - softLiquidationParams.softLCF1
            ) + softLiquidationParams.softLCF1,
            softLiquidationParams.softLCF2
        );
    }

    function _softLIF(SoftLiquidationParams memory softLiquidationParams, uint256 ltv) internal view returns (uint256) {
        return UtilsLib.min(
            (ltv - softLiquidationParams.softLltv).wDivDown(marketParams.lltv - softLiquidationParams.softLltv).wMulDown(
                softLiquidationParams.softLIF2 - softLiquidationParams.softLIF1
            ) + softLiquidationParams.softLIF1,
            softLiquidationParams.softLIF2
        );
    }

    function _getBorrowBounds(
        SoftLiquidationParams memory softLiquidationParams,
        MarketParams memory _marketParams,
        uint256 collateralAmount
    ) internal view returns (uint256, uint256, uint256) {
        uint256 collateralPrice = IOracle(softLiquidationParams.softLiquidationOracle).price();
        uint256 collateralQuoted = collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE);
        uint256 borrowSoftLiquidationThreshold = collateralQuoted.wMulDown(softLiquidationParams.softLltv);
        uint256 borrowLiquidationThreshold = collateralQuoted.wMulDown(_marketParams.lltv);

        return (collateralQuoted, borrowSoftLiquidationThreshold, borrowLiquidationThreshold);
    }
}
