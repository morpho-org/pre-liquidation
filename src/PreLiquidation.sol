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

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Pre Liquidation Contract for Morpho
contract PreLiquidation is IPreLiquidation {
    using MarketParamsLib for MarketParams;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */
    IMorpho public immutable MORPHO;
    Id public immutable marketId;

    // Market parameters
    address public immutable loanToken;
    address public immutable collateralToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;

    // Pre-liquidation parameters
    uint256 public immutable preLltv;
    uint256 public immutable closeFactor;
    uint256 public immutable preLiquidationIncentive;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho

    constructor(MarketParams memory _marketParams, PreLiquidationParams memory _preLiquidationParams, address morpho) {
        require(preLltv < lltv, ErrorsLib.PreLltvTooHigh(preLltv, lltv));

        MORPHO = IMorpho(morpho);

        loanToken = _marketParams.loanToken;
        collateralToken = _marketParams.collateralToken;
        oracle = _marketParams.oracle;
        irm = _marketParams.irm;
        lltv = _marketParams.lltv;
        marketId = _marketParams.id();

        preLltv = _preLiquidationParams.preLltv;
        closeFactor = _preLiquidationParams.closeFactor;
        preLiquidationIncentive = _preLiquidationParams.preLiquidationIncentive;

        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        ERC20(loanToken).safeApprove(address(MORPHO), type(uint256).max);
    }

    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external {
        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput(seizedAssets, repaidShares)
        );
        uint256 collateralPrice = IOracle(oracle).price();

        MarketParams memory marketParams = MarketParams(loanToken, collateralToken, oracle, irm, lltv);
        MORPHO.accrueInterest(marketParams);
        require(_isPreLiquidatable(borrower, collateralPrice), ErrorsLib.NotPreLiquidatablePosition());

        Market memory market = MORPHO.market(marketId);
        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

            repaidShares = seizedAssetsQuoted.wDivUp(preLiquidationIncentive).toSharesUp(
                market.totalBorrowAssets, market.totalBorrowShares
            );
        } else {
            seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                preLiquidationIncentive
            ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        // Check if liquidation is ok with close factor
        uint256 repayableShares = MORPHO.position(marketId, borrower).borrowShares.wMulDown(closeFactor);
        require(repaidShares <= repayableShares, ErrorsLib.PreLiquidationTooLarge(repaidShares, repayableShares));

        bytes memory callbackData = abi.encode(seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.PreLiquidate(marketId, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets);
    }

    function onMorphoRepay(uint256 repaidAssets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), ErrorsLib.NotMorpho());
        (uint256 seizedAssets, address borrower, address liquidator, bytes memory data) =
            abi.decode(callbackData, (uint256, address, address, bytes));

        MarketParams memory marketParams = MarketParams(loanToken, collateralToken, oracle, irm, lltv);
        MORPHO.withdrawCollateral(marketParams, seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            IPreLiquidationCallback(liquidator).onPreLiquidate(repaidAssets, data);
        }

        ERC20(loanToken).safeTransferFrom(liquidator, address(this), repaidAssets);
    }

    function _isPreLiquidatable(address borrower, uint256 collateralPrice) internal view returns (bool) {
        Position memory borrowerPosition = MORPHO.position(marketId, borrower);
        Market memory market = MORPHO.market(marketId);

        uint256 borrowed =
            uint256(borrowerPosition.borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 borrowThreshold =
            uint256(borrowerPosition.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(preLltv);

        return borrowThreshold < borrowed;
    }
}
