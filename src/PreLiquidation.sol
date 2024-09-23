// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {IPreLiquidationCallback} from "./interfaces/IPreLiquidationCallback.sol";
import {IPreLiquidation, PreLiquidationParams} from "./interfaces/IPreLiquidation.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";

/// @title PreLiquidation
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Contract for Morpho
contract PreLiquidation is IPreLiquidation, IMorphoRepayCallback {
    using MarketParamsLib for MarketParams;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */
    IMorpho public immutable MORPHO;
    Id public immutable ID;

    // Market parameters
    address public immutable LOAN_TOKEN;
    address public immutable COLLATERAL_TOKEN;
    address public immutable ORACLE;
    address public immutable IRM;
    uint256 public immutable LLTV;

    // Pre-liquidation parameters
    uint256 public immutable PRE_LLTV;
    uint256 public immutable CLOSE_FACTOR;
    uint256 public immutable PRE_LIQUIDATION_INCENTIVE;
    address public immutable PRE_LIQUIDATION_ORACLE;

    constructor(Id id, PreLiquidationParams memory preLiquidationParams, address morpho) {
        require(IMorpho(morpho).market(id).lastUpdate != 0, ErrorsLib.NonexistentMarket());
        MarketParams memory marketParams = IMorpho(morpho).idToMarketParams(id);
        require(preLiquidationParams.preLltv < marketParams.lltv, ErrorsLib.PreLltvTooHigh());

        MORPHO = IMorpho(morpho);

        ID = id;

        LOAN_TOKEN = marketParams.loanToken;
        COLLATERAL_TOKEN = marketParams.collateralToken;
        ORACLE = marketParams.oracle;
        IRM = marketParams.irm;
        LLTV = marketParams.lltv;

        PRE_LLTV = preLiquidationParams.preLltv;
        CLOSE_FACTOR = preLiquidationParams.closeFactor;
        PRE_LIQUIDATION_INCENTIVE = preLiquidationParams.preLiquidationIncentive;
        PRE_LIQUIDATION_ORACLE = preLiquidationParams.preLiquidationOracle;

        ERC20(marketParams.loanToken).safeApprove(morpho, type(uint256).max);
    }

    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external {
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput());
        uint256 collateralPrice = IOracle(PRE_LIQUIDATION_ORACLE).price();

        MarketParams memory marketParams = MarketParams(LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, LLTV);
        MORPHO.accrueInterest(marketParams);
        require(_isPreLiquidatable(borrower, collateralPrice), ErrorsLib.NotPreLiquidatablePosition());

        Market memory market = MORPHO.market(ID);
        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

            repaidShares = seizedAssetsQuoted.wDivUp(PRE_LIQUIDATION_INCENTIVE).toSharesUp(
                market.totalBorrowAssets, market.totalBorrowShares
            );
        } else {
            seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                PRE_LIQUIDATION_INCENTIVE
            ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        // Check if liquidation is ok with close factor
        uint256 repayableShares = MORPHO.position(ID, borrower).borrowShares.wMulDown(CLOSE_FACTOR);
        require(repaidShares <= repayableShares, ErrorsLib.PreLiquidationTooLarge(repaidShares, repayableShares));

        bytes memory callbackData = abi.encode(seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.PreLiquidate(ID, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets);
    }

    function onMorphoRepay(uint256 repaidAssets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), ErrorsLib.NotMorpho());
        (uint256 seizedAssets, address borrower, address liquidator, bytes memory data) =
            abi.decode(callbackData, (uint256, address, address, bytes));

        MarketParams memory marketParams = MarketParams(LOAN_TOKEN, COLLATERAL_TOKEN, ORACLE, IRM, LLTV);
        MORPHO.withdrawCollateral(marketParams, seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            IPreLiquidationCallback(liquidator).onPreLiquidate(repaidAssets, data);
        }

        ERC20(LOAN_TOKEN).safeTransferFrom(liquidator, address(this), repaidAssets);
    }

    function _isPreLiquidatable(address borrower, uint256 collateralPrice) internal view returns (bool) {
        Position memory borrowerPosition = MORPHO.position(ID, borrower);
        Market memory market = MORPHO.market(ID);

        uint256 borrowed =
            uint256(borrowerPosition.borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 borrowThreshold =
            uint256(borrowerPosition.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(PRE_LLTV);

        return borrowed > borrowThreshold;
    }
}
