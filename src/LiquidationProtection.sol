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
import {ILiquidationProtection, SubscriptionParams} from "./interfaces/ILiquidationProtection.sol";

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Liquidation Protection Contract for Morpho
contract LiquidationProtection is ILiquidationProtection {
    using MarketParamsLib for MarketParams;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */
    IMorpho public immutable MORPHO;
    Id public immutable marketId;

    uint256 public immutable prelltv;
    uint256 public immutable closeFactor;
    uint256 public immutable preLiquidationIncentive;
    uint256 public immutable lltv;

    address immutable collateralToken;
    address immutable loanToken;
    address immutable irm;
    address immutable oracle;

    /* STORAGE */
    mapping(address => bool) public subscriptions;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho

    constructor(MarketParams memory _marketParams, SubscriptionParams memory _subscriptionParams, address morpho) {
        MORPHO = IMorpho(morpho);

        prelltv = _subscriptionParams.prelltv;
        closeFactor = _subscriptionParams.closeFactor;
        preLiquidationIncentive = _subscriptionParams.preLiquidationIncentive;

        lltv = _marketParams.lltv;
        collateralToken = _marketParams.collateralToken;
        loanToken = _marketParams.loanToken;
        irm = _marketParams.irm;
        oracle = _marketParams.oracle;

        marketId = _marketParams.id();
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?
        require(prelltv < lltv, ErrorsLib.PreLltvTooHigh(prelltv, lltv));

        ERC20(loanToken).safeApprove(address(MORPHO), type(uint256).max);
    }

    function subscribe() external {
        subscriptions[msg.sender] = true;

        emit EventsLib.Subscribe(msg.sender);
    }

    function unsubscribe() external {
        subscriptions[msg.sender] = false;

        emit EventsLib.Unsubscribe(msg.sender);
    }

    function preliquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external {
        require(subscriptions[borrower], ErrorsLib.InvalidSubscription());

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

        emit EventsLib.PreLiquidate(borrower, marketId, msg.sender, repaidAssets, repaidShares, seizedAssets);
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
        uint256 preLiquidationBorrowThreshold =
            uint256(borrowerPosition.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(prelltv);

        return preLiquidationBorrowThreshold < borrowed;
    }
}
