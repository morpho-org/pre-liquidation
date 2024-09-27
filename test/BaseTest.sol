// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IrmMock} from "../src/mocks/IrmMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";

import {MarketParams, IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {
    ORACLE_PRICE_SCALE,
    MAX_LIQUIDATION_INCENTIVE_FACTOR,
    LIQUIDATION_CURSOR
} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";

import {PreLiquidationParams} from "../src/interfaces/IPreLiquidation.sol";

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
    uint256 internal marketLIF;

    MarketParams internal marketParams;
    Id internal id;

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

        marketLIF = UtilsLib.min(
            MAX_LIQUIDATION_INCENTIVE_FACTOR, WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv))
        );

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(MORPHO), type(uint256).max);
        vm.stopPrank();

        vm.prank(BORROWER);
        collateralToken.approve(address(MORPHO), type(uint256).max);
    }

    function boundPreLiquidationParameters(
        PreLiquidationParams memory preLiquidationParams,
        uint256 minPreLltv,
        uint256 maxPreLltv,
        uint256 minCloseFactor,
        uint256 maxCloseFactor,
        uint256 minPreLIF,
        uint256 maxPreLIF,
        address preLiqOracle
    ) internal pure returns (PreLiquidationParams memory) {
        preLiquidationParams.preLltv = bound(preLiquidationParams.preLltv, minPreLltv, maxPreLltv);
        preLiquidationParams.preCF1 = bound(preLiquidationParams.preCF1, minCloseFactor, maxCloseFactor);
        preLiquidationParams.preCF2 = bound(preLiquidationParams.preCF2, minCloseFactor, maxCloseFactor);
        preLiquidationParams.preLIF1 = bound(preLiquidationParams.preLIF1, minPreLIF, maxPreLIF);
        preLiquidationParams.preLIF2 = bound(preLiquidationParams.preLIF2, minPreLIF, maxPreLIF);
        preLiquidationParams.preLiquidationOracle = preLiqOracle;

        return preLiquidationParams;
    }
}
