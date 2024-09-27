// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {ORACLE_PRICE_SCALE} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
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
/// @notice A linear LIF and linear CF pre-liquidation contract for Morpho.
contract PreLiquidation is IPreLiquidation, IMorphoRepayCallback {
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */

    /// @notice Morpho's address.
    IMorpho public immutable MORPHO;
    /// @notice The id of the Morpho Market specific to the PreLiquidation contract.
    Id public immutable ID;

    // Market parameters
    address internal immutable LOAN_TOKEN;
    address internal immutable COLLATERAL_TOKEN;
    address internal immutable ORACLE;
    address internal immutable IRM;
    uint256 internal immutable LLTV;

    // Pre-liquidation parameters
    uint256 internal immutable PRE_LLTV;
    uint256 internal immutable CLOSE_FACTOR_1;
    uint256 internal immutable CLOSE_FACTOR_2;
    uint256 internal immutable PRE_LIF_1;
    uint256 internal immutable PRE_LIF_2;
    address internal immutable PRE_LIQUIDATION_ORACLE;

    /// @notice The Morpho market parameters specific to the PreLiquidation contract.
    function marketParams() public view returns (MarketParams memory) {
        return MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    /// @notice The pre-liquidation parameters specific to the PreLiquidation contract.
    function preLiquidationParams() external view returns (PreLiquidationParams memory) {
        return PreLiquidationParams({
            preLltv: PRE_LLTV,
            closeFactor1: CLOSE_FACTOR_1,
            closeFactor2: CLOSE_FACTOR_2,
            preLIF1: PRE_LIF_1,
            preLIF2: PRE_LIF_2,
            preLiquidationOracle: PRE_LIQUIDATION_ORACLE
        });
    }

    /* CONSTRUCTOR */

    /// @dev Initializes the PreLiquidation contract.
    /// @param morpho The address of the Morpho protocol.
    /// @param id The id of the Morpho market on which pre-liquidations will occur.
    /// @param _preLiquidationParams The pre-liquidation parameters.
    /// @dev The pre-liquidation LLTV should be strictly lower than the market LLTV.
    /// @dev The pre-liquidation close factor parameters should be increasing.
    /// @dev The pre-liquidation LIF parameters should be higher than 100% (1 WAD) and increasing.
    /// @dev The close factor is the maximum proportion of debt that can be pre-liquidated at once.
    /// It is computed as the weighted average of closeFactor1 and closeFactor2
    /// proportionally to LTV-preLltv and LLTV-LTV. It is also capped by 100% (1 WAD).
    /// @dev The pre-liquidation incentive factor (preLIF) corresponds to the factor
    /// which is multiplied by the repaid debt to compute the seized collatearl.
    /// It is computed as the weighted average of preLIF1 and preLIF2
    /// proportionally to LTV-preLltv and LLTV-LTV.
    constructor(address morpho, Id id, PreLiquidationParams memory _preLiquidationParams) {
        require(IMorpho(morpho).market(id).lastUpdate != 0, ErrorsLib.NonexistentMarket());
        MarketParams memory _marketParams = IMorpho(morpho).idToMarketParams(id);
        require(_preLiquidationParams.preLltv < _marketParams.lltv, ErrorsLib.PreLltvTooHigh());
        require(
            _preLiquidationParams.closeFactor2 >= _preLiquidationParams.closeFactor1,
            ErrorsLib.CloseFactorNotIncreasing()
        );
        require(_preLiquidationParams.preLIF1 >= WAD, ErrorsLib.preLIFTooLow());
        require(_preLiquidationParams.preLIF2 >= _preLiquidationParams.preLIF1, ErrorsLib.preLIFNotIncreasing());

        MORPHO = IMorpho(morpho);

        ID = id;

        LOAN_TOKEN = _marketParams.loanToken;
        COLLATERAL_TOKEN = _marketParams.collateralToken;
        ORACLE = _marketParams.oracle;
        IRM = _marketParams.irm;
        LLTV = _marketParams.lltv;

        PRE_LLTV = _preLiquidationParams.preLltv;
        CLOSE_FACTOR_1 = _preLiquidationParams.closeFactor1;
        CLOSE_FACTOR_2 = _preLiquidationParams.closeFactor2;
        PRE_LIF_1 = _preLiquidationParams.preLIF1;
        PRE_LIF_2 = _preLiquidationParams.preLIF2;
        PRE_LIQUIDATION_ORACLE = _preLiquidationParams.preLiquidationOracle;

        ERC20(LOAN_TOKEN).safeApprove(morpho, type(uint256).max);
    }

    /* PRE-LIQUIDATION */

    /// @notice Pre-liquidates the given borrower on the market of this contract and with the parameters of this contract.
    /// @dev Either `seizedAssets` or `repaidShares` should be zero.
    /// @param borrower The owner of the position.
    /// @param seizedAssets The amount of collateral to seize.
    /// @param repaidShares The amount of shares to repay.
    /// @param data Arbitrary data to pass to the `onPreLiquidate` callback. Pass empty data if not needed.
    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external {
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput());

        MORPHO.accrueInterest(marketParams());

        Market memory market = MORPHO.market(ID);
        Position memory position = MORPHO.position(ID, borrower);

        uint256 collateralPrice = IOracle(PRE_LIQUIDATION_ORACLE).price();
        uint256 collateralQuoted = uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE);

        uint256 borrowed = uint256(position.borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 borrowThreshold = collateralQuoted.wMulDown(PRE_LLTV);

        require(borrowed > borrowThreshold, ErrorsLib.NotPreLiquidatablePosition());

        uint256 ltv = borrowed.wDivUp(collateralQuoted);
        uint256 preLIF = UtilsLib.min(
            (ltv - PRE_LLTV).wMulDown(PRE_LIF_2 - PRE_LIF_1).wDivDown(LLTV - PRE_LLTV) + PRE_LIF_1, PRE_LIF_2
        );

        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

            repaidShares =
                seizedAssetsQuoted.wDivUp(preLIF).toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                preLIF
            ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        uint256 borrowerShares = position.borrowShares;
        uint256 closeFactor = UtilsLib.min(
            (ltv - PRE_LLTV).wMulDown(CLOSE_FACTOR_2 - CLOSE_FACTOR_1).wDivDown(LLTV - PRE_LLTV) + CLOSE_FACTOR_1,
            CLOSE_FACTOR_2
        );
        uint256 repayableShares = borrowerShares.wMulDown(closeFactor);
        require(repaidShares <= repayableShares, ErrorsLib.PreLiquidationTooLarge(repaidShares, repayableShares));

        bytes memory callbackData = abi.encode(seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams(), 0, repaidShares, borrower, callbackData);

        emit EventsLib.PreLiquidate(ID, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets);
    }

    /// @notice Morpho callback after repay call.
    /// @dev During pre-liquidation, Morpho will call the `onMorphoRepay` callback function in `PreLiquidation` using the provided data.
    /// This mechanism enables the withdrawal of the position’s collateral before the debt repayment occurs,
    /// and can also trigger a pre-liquidator callback. The pre-liquidator callback can be used to swap
    /// the seized collateral into the asset being repaid, facilitating liquidation without the need for a flashloan.
    function onMorphoRepay(uint256 repaidAssets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), ErrorsLib.NotMorpho());
        (uint256 seizedAssets, address borrower, address liquidator, bytes memory data) =
            abi.decode(callbackData, (uint256, address, address, bytes));

        MORPHO.withdrawCollateral(marketParams(), seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            IPreLiquidationCallback(liquidator).onPreLiquidate(repaidAssets, data);
        }

        ERC20(LOAN_TOKEN).safeTransferFrom(liquidator, address(this), repaidAssets);
    }
}
