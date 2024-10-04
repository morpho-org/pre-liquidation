// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IMorphoRepayCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import {ISoftLiquidation, SoftLiquidationParams} from "./interfaces/ISoftLiquidation.sol";
import {ISoftLiquidationCallback} from "./interfaces/ISoftLiquidationCallback.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";

import {ORACLE_PRICE_SCALE} from "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {WAD, MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

/// @title SoftLiquidation
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice A linear LIF and linear LCF soft-liquidation contract for Morpho.
contract SoftLiquidation is ISoftLiquidation, IMorphoRepayCallback {
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;
    /// @notice The id of the Morpho Market specific to the SoftLiquidation contract.
    Id public immutable ID;

    // Market parameters
    address internal immutable LOAN_TOKEN;
    address internal immutable COLLATERAL_TOKEN;
    address internal immutable ORACLE;
    address internal immutable IRM;
    uint256 internal immutable LLTV;

    // Soft-liquidation parameters
    uint256 internal immutable PRE_LLTV;
    uint256 internal immutable PRE_LCF_1;
    uint256 internal immutable PRE_LCF_2;
    uint256 internal immutable PRE_LIF_1;
    uint256 internal immutable PRE_LIF_2;
    address internal immutable PRE_LIQUIDATION_ORACLE;

    /// @notice The Morpho market parameters specific to the SoftLiquidation contract.
    function marketParams() public view returns (MarketParams memory) {
        return MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    /// @notice The soft-liquidation parameters specific to the SoftLiquidation contract.
    function softLiquidationParams() external view returns (SoftLiquidationParams memory) {
        return SoftLiquidationParams({
            softLltv: PRE_LLTV,
            softLCF1: PRE_LCF_1,
            softLCF2: PRE_LCF_2,
            softLIF1: PRE_LIF_1,
            softLIF2: PRE_LIF_2,
            softLiquidationOracle: PRE_LIQUIDATION_ORACLE
        });
    }

    /* CONSTRUCTOR */

    /// @dev Initializes the SoftLiquidation contract.
    /// @param morpho The address of the Morpho contract.
    /// @param id The id of the Morpho market on which soft-liquidations will occur.
    /// @param _softLiquidationParams The soft-liquidation parameters.
    /// @dev The following requirements should be met:
    /// - softLltv < LLTV;
    /// - softLCF1 <= softLCF2;
    /// - WAD <= softLIF1 <= softLIF2.
    constructor(address morpho, Id id, SoftLiquidationParams memory _softLiquidationParams) {
        require(IMorpho(morpho).market(id).lastUpdate != 0, ErrorsLib.NonexistentMarket());
        MarketParams memory _marketParams = IMorpho(morpho).idToMarketParams(id);
        require(_softLiquidationParams.softLltv < _marketParams.lltv, ErrorsLib.SoftLltvTooHigh());
        require(_softLiquidationParams.softLCF1 <= _softLiquidationParams.softLCF2, ErrorsLib.SoftLCFDecreasing());
        require(WAD <= _softLiquidationParams.softLIF1, ErrorsLib.SoftLIFTooLow());
        require(_softLiquidationParams.softLIF1 <= _softLiquidationParams.softLIF2, ErrorsLib.SoftLIFDecreasing());

        MORPHO = IMorpho(morpho);

        ID = id;

        LOAN_TOKEN = _marketParams.loanToken;
        COLLATERAL_TOKEN = _marketParams.collateralToken;
        ORACLE = _marketParams.oracle;
        IRM = _marketParams.irm;
        LLTV = _marketParams.lltv;

        PRE_LLTV = _softLiquidationParams.softLltv;
        PRE_LCF_1 = _softLiquidationParams.softLCF1;
        PRE_LCF_2 = _softLiquidationParams.softLCF2;
        PRE_LIF_1 = _softLiquidationParams.softLIF1;
        PRE_LIF_2 = _softLiquidationParams.softLIF2;
        PRE_LIQUIDATION_ORACLE = _softLiquidationParams.softLiquidationOracle;

        ERC20(_marketParams.loanToken).safeApprove(morpho, type(uint256).max);
    }

    /* PRE-LIQUIDATION */

    /// @notice Soft-liquidates the given borrower on the market of this contract and with the parameters of this
    /// contract.
    /// @param borrower The owner of the position.
    /// @param seizedAssets The amount of collateral to seize.
    /// @param repaidShares The amount of shares to repay.
    /// @param data Arbitrary data to pass to the `onSoftLiquidate` callback. Pass empty data if not needed.
    /// @return seizedAssets The amount of collateral seized.
    /// @return repaidAssets The amount of debt repaid.
    /// @dev Either `seizedAssets` or `repaidShares` should be zero.
    /// @dev Reverts if the account is still liquidatable on Morpho after the soft-liquidation (withdrawCollateral will
    /// fail). This can happen if either the LIF is bigger than 1/LLTV, or if the account is already unhealthy on
    /// Morpho.
    /// @dev The soft-liquidation close factor (softLCF) is the maximum proportion of debt that can be soft-liquidated at
    /// once. It increases linearly from softLCF1 at softLltv to softLCF2 at LLTV.
    /// @dev The soft-liquidation incentive factor (softLIF) is the factor by which the repaid debt is multiplied to
    /// compute the seized collateral. It increases linearly from softLIF1 at softLltv to softLIF2 at LLTV.
    function softLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data)
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
        uint256 ltv = borrowed.wDivUp(collateralQuoted);

        // The following require is equivalent to checking that borrowed > collateralQuoted.wMulDown(PRE_LLTV).
        require(ltv > PRE_LLTV, ErrorsLib.NotSoftLiquidatablePosition());

        uint256 softLIF = UtilsLib.min(
            (ltv - PRE_LLTV).wDivDown(LLTV - PRE_LLTV).wMulDown(PRE_LIF_2 - PRE_LIF_1) + PRE_LIF_1, PRE_LIF_2
        );

        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

            repaidShares =
                seizedAssetsQuoted.wDivUp(softLIF).toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                softLIF
            ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        // Note that the soft-liquidation close factor can be greater than WAD (100%). In this case the position can be
        // fully soft-liquidated.
        uint256 softLCF = UtilsLib.min(
            (ltv - PRE_LLTV).wDivDown(LLTV - PRE_LLTV).wMulDown(PRE_LCF_2 - PRE_LCF_1) + PRE_LCF_1, PRE_LCF_2
        );
        uint256 repayableShares = uint256(position.borrowShares).wMulDown(softLCF);
        require(repaidShares <= repayableShares, ErrorsLib.SoftLiquidationTooLarge(repaidShares, repayableShares));

        bytes memory callbackData = abi.encode(seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams(), 0, repaidShares, borrower, callbackData);

        emit EventsLib.SoftLiquidate(ID, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets);

        return (seizedAssets, repaidAssets);
    }

    /// @notice Morpho callback after repay call.
    /// @dev During soft-liquidation, Morpho will call the `onMorphoRepay` callback function in `SoftLiquidation` using
    /// the provided `data`.
    function onMorphoRepay(uint256 repaidAssets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), ErrorsLib.NotMorpho());
        (uint256 seizedAssets, address borrower, address liquidator, bytes memory data) =
            abi.decode(callbackData, (uint256, address, address, bytes));

        MORPHO.withdrawCollateral(marketParams(), seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            ISoftLiquidationCallback(liquidator).onSoftLiquidate(repaidAssets, data);
        }

        ERC20(LOAN_TOKEN).safeTransferFrom(liquidator, address(this), repaidAssets);
    }
}
