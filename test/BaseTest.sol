// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IrmMock} from "../src/mocks/IrmMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";

import {MarketParams, IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {ORACLE_PRICE_SCALE} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";

contract BaseTest is Test {
    using MarketParamsLib for MarketParams;

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

    function boundPreLiquidationParameters(
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        uint256 minPreLltv,
        uint256 maxPreLltv,
        uint256 minCloseFactor,
        uint256 maxCloseFactor,
        uint256 minPreLIF,
        uint256 maxPreLIF,
        address preLiqOracle
    ) internal pure returns (uint256, uint256, uint256, uint256, uint256, address) {
        return (
            bound(preLltv, minPreLltv, maxPreLltv),
            bound(preCF1, minCloseFactor, maxCloseFactor),
            bound(preCF2, minCloseFactor, maxCloseFactor),
            bound(preLIF1, minPreLIF, maxPreLIF),
            bound(preLIF2, minPreLIF, maxPreLIF),
            preLiqOracle
        );
    }
}
