// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMorphoLiquidateCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

struct SubscriptionParams {
    uint256 slltv;
    uint256 closeFactor;
    uint256 liquidationIncentive;
}

/// @title Morpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The Liquidation Protection Contract for Morpho
contract LiquidationProtection {
    using MarketParamsLib for MarketParams;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;
    using SafeTransferLib for ERC20;

    /* IMMUTABLE */
    IMorpho immutable MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    /* STORAGE */
    mapping(bytes32 => SubscriptionParams) public subscriptions;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho
    // TODO potential gas opti (keeping marketparams in SubscriptionParams instead of Id?)

    function subscribe(Id marketId, SubscriptionParams calldata subscriptionParams) public {
        MarketParams memory marketParams = MORPHO.idToMarketParams(marketId);

        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId);

        require(subscriptionParams.slltv < marketParams.lltv, "Liquidation threshold higher than market LLTV");
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        subscriptions[subscriptionId] = subscriptionParams;

        emit EventsLib.Subscribe(
            msg.sender,
            marketId,
            subscriptionParams.slltv,
            subscriptionParams.closeFactor,
            subscriptionParams.liquidationIncentive
        );
    }

    function unsubscribe(Id marketId) public {
        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId);

        delete subscriptions[subscriptionId];

        emit EventsLib.Unsubscribe(msg.sender, marketId);
    }

    function liquidate(
        MarketParams calldata marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) public {
        bytes32 subscriptionId = computeSubscriptionId(borrower, marketParams.id());

        require(
            subscriptions[subscriptionId].slltv != 0 && subscriptions[subscriptionId].closeFactor != 0
                && subscriptions[subscriptionId].liquidationIncentive != 0,
            "Non-valid subscription"
        );

        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), "Inconsistent input");
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        MORPHO.accrueInterest(marketParams);
        require(
            !_isHealthy(marketParams.id(), borrower, collateralPrice, subscriptions[subscriptionId].slltv),
            "Position is healthy"
        );

        // Compute seizedAssets or repaidShares and repaidAssets
        Market memory marketState = MORPHO.market(marketParams.id());

        {
            uint256 liquidationIncentive = subscriptions[subscriptionId].liquidationIncentive;
            if (seizedAssets > 0) {
                uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

                repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentive).toSharesUp(
                    marketState.totalBorrowAssets, marketState.totalBorrowShares
                );
            } else {
                seizedAssets = repaidShares.toAssetsDown(marketState.totalBorrowAssets, marketState.totalBorrowShares)
                    .wMulDown(liquidationIncentive).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }
        uint256 repaidAssets = repaidShares.toAssetsUp(marketState.totalBorrowAssets, marketState.totalBorrowShares);

        // Check if liquidation is ok with close factor
        Position memory borrowerPosition = MORPHO.position(marketParams.id(), borrower);
        require(
            borrowerPosition.collateral.wMulDown(subscriptions[subscriptionId].closeFactor) > seizedAssets,
            "Cannot liquidate more than close factor"
        );

        bytes memory callbackData = abi.encode(marketParams, seizedAssets, repaidAssets, borrower, msg.sender, data);
        MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.Liquidate(
            marketParams.id(), msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, 0, 0
        );
    }

    function onMorphoRepay(uint256 assets, bytes calldata callbackData) external {
        (
            MarketParams memory marketParams,
            uint256 seizedAssets,
            uint256 repaidAssets,
            address borrower,
            address liquidator,
            bytes memory data
        ) = abi.decode(callbackData, (MarketParams, uint256, uint256, address, address, bytes));

        MORPHO.withdrawCollateral(marketParams, seizedAssets, borrower, liquidator);

        if (data.length > 0) IMorphoLiquidateCallback(liquidator).onMorphoLiquidate(assets, data);

        ERC20(marketParams.loanToken).safeTransferFrom(liquidator, address(this), repaidAssets);

        ERC20(marketParams.loanToken).safeApprove(address(MORPHO), repaidAssets);
    }

    function computeSubscriptionId(address borrower, Id marketId) public pure returns (bytes32) {
        return keccak256(abi.encode(borrower, marketId));
    }

    function _isHealthy(Id id, address borrower, uint256 collateralPrice, uint256 ltvThreshold)
        internal
        view
        returns (bool)
    {
        Position memory borrowerPosition = MORPHO.position(id, borrower);
        Market memory marketState = MORPHO.market(id);

        uint256 borrowed = uint256(borrowerPosition.borrowShares).toAssetsUp(
            marketState.totalBorrowAssets, marketState.totalBorrowShares
        );
        uint256 maxBorrow =
            uint256(borrowerPosition.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(ltvThreshold);

        return maxBorrow >= borrowed;
    }
}
