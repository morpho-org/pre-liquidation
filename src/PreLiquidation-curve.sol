// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import {IPreLiquidation, PreLiquidationParams} from "./interfaces/IPreLiquidation.sol";
import {IPreLiquidationCallback} from "./interfaces/IPreLiquidationCallback.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";

import {ORACLE_PRICE_SCALE} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title PreLiquidationCurve
/// @notice Pre-liquidation with quadratic convex curve (slow start, fast ramp near LLTV)
contract PreLiquidationCurve is IPreLiquidation, IMorphoRepayCallback {
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IMorpho public immutable MORPHO;
    Id public immutable ID;

    address internal immutable LOAN_TOKEN;
    address internal immutable COLLATERAL_TOKEN;
    address internal immutable ORACLE;
    address internal immutable IRM;
    uint256 internal immutable LLTV;

    // Pre-liquidation parameters
    uint256 internal immutable PRE_LLTV;
    uint256 internal immutable PRE_LCF_1;
    uint256 internal immutable PRE_LCF_2;
    uint256 internal immutable PRE_LIF_1;
    uint256 internal immutable PRE_LIF_2;
    address internal immutable PRE_LIQUIDATION_ORACLE;

    constructor(address morpho, Id id, PreLiquidationParams memory _preLiquidationParams) {
        require(IMorpho(morpho).market(id).lastUpdate != 0, ErrorsLib.NonexistentMarket());
        MarketParams memory _marketParams = IMorpho(morpho).idToMarketParams(id);

        // Parameter validations (same as original)
        require(_preLiquidationParams.preLltv < _marketParams.lltv, ErrorsLib.PreLltvTooHigh());
        require(_preLiquidationParams.preLCF1 <= _preLiquidationParams.preLCF2, ErrorsLib.PreLCFDecreasing());
        require(_preLiquidationParams.preLCF1 <= WAD, ErrorsLib.PreLCFTooHigh());
        require(WAD <= _preLiquidationParams.preLIF1, ErrorsLib.PreLIFTooLow());
        require(_preLiquidationParams.preLIF1 <= _preLiquidationParams.preLIF2, ErrorsLib.PreLIFDecreasing());
        require(_preLiquidationParams.preLIF2 <= WAD.wDivDown(_marketParams.lltv), ErrorsLib.PreLIFTooHigh());

        MORPHO = IMorpho(morpho);
        ID = id;

        LOAN_TOKEN = _marketParams.loanToken;
        COLLATERAL_TOKEN = _marketParams.collateralToken;
        ORACLE = _marketParams.oracle;
        IRM = _marketParams.irm;
        LLTV = _marketParams.lltv;

        PRE_LLTV = _preLiquidationParams.preLltv;
        PRE_LCF_1 = _preLiquidationParams.preLCF1;
        PRE_LCF_2 = _preLiquidationParams.preLCF2;
        PRE_LIF_1 = _preLiquidationParams.preLIF1;
        PRE_LIF_2 = _preLiquidationParams.preLIF2;
        PRE_LIQUIDATION_ORACLE = _preLiquidationParams.preLiquidationOracle;

        // Approve Morpho to spend loan tokens (required for repay)
        ERC20(_marketParams.loanToken).safeApprove(morpho, type(uint256).max);
    }

    function marketParams() public view returns (MarketParams memory) {
        return MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    function preLiquidationParams() external view returns (PreLiquidationParams memory) {
        return PreLiquidationParams({
            preLltv: PRE_LLTV,
            preLCF1: PRE_LCF_1,
            preLCF2: PRE_LCF_2,
            preLIF1: PRE_LIF_1,
            preLIF2: PRE_LIF_2,
            preLiquidationOracle: PRE_LIQUIDATION_ORACLE
        });
    }

    /// @notice Pre-liquidates the borrower using quadratic convex interpolation
    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data)
        external
        returns (uint256, uint256)
    {
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput());

        MORPHO.accrueInterest(marketParams());

        Market memory market = MORPHO.market(ID);
        Position memory position = MORPHO.position(ID, borrower);

        uint256 collateralPrice = IOracle(PRE_LIQUIDATION_ORACLE).price();
        uint256 collateralQuoted = uint256(position.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE);
        uint256 borrowed = uint256(position.borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);

        // Position must be in pre-liquidation zone only
        require(borrowed <= collateralQuoted.wMulDown(LLTV), ErrorsLib.LiquidatablePosition());
        require(borrowed > collateralQuoted.wMulDown(PRE_LLTV), ErrorsLib.NotPreLiquidatablePosition());

        uint256 ltv = borrowed.wDivUp(collateralQuoted);
        uint256 quotient = (ltv - PRE_LLTV).wDivDown(LLTV - PRE_LLTV);

        // Quadratic convex curve: slow at start (near PRE_LLTV), accelerates near LLTV
        uint256 qPow2 = quotient.mulDivDown(quotient, WAD); // q²
        uint256 preLIF = PRE_LIF_1 + (PRE_LIF_2 - PRE_LIF_1).mulDivDown(qPow2, WAD);
        uint256 preLCF = PRE_LCF_1 + (PRE_LCF_2 - PRE_LCF_1).mulDivDown(qPow2, WAD);

        // Apply to seized/repaid calculation
        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);
            repaidShares = seizedAssetsQuoted.wDivUp(preLIF).toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares)
                .wMulDown(preLIF)
                .mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        // Limit by preLCF (can be > WAD = allow full close near LLTV)
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(preLCF);
        require(repaidShares <= repayableShares, ErrorsLib.PreLiquidationTooLarge(repaidShares, repayableShares));

        bytes memory callbackData = abi.encode(seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets, ) = MORPHO.repay(marketParams(), 0, repaidShares, borrower, callbackData);

        emit EventsLib.PreLiquidate(ID, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets);

        return (seizedAssets, repaidAssets);
    }

    /// @notice Morpho callback after repay
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