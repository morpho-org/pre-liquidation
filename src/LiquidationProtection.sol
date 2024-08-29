// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Id, MarketParams, IMorpho, Position, Market} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IERC20} from "../lib/morpho-blue/src/interfaces/IERC20.sol";
import {SafeTransferLib} from "../lib/morpho-blue/src/libraries/SafeTransferLib.sol";
import {IMorphoLiquidateCallback} from "../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import "../lib/morpho-blue/src/libraries/ConstantsLib.sol";
import {MathLib} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";

struct SubscriptionParams {
    Id marketId;
    address borrower;
    uint256 slltv;
    uint256 closeFactor;
    uint256 liquidationIncentive;
}

contract LiquidationProtection {
    using MarketParamsLib for MarketParams;
    using UtilsLib for uint256;
    using SafeTransferLib for IERC20;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;

    address immutable MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    mapping(uint256 => SubscriptionParams) subscriptions;
    mapping(uint256 => bool) isValidSubscriptionId;
    uint256 nbSubscriptions;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho

    function subscribe(
        SubscriptionParams calldata subscriptionParams
    ) public returns (uint256) {
        IMorpho morpho = IMorpho(MORPHO);
        MarketParams memory marketParams = morpho.idToMarketParams(
            subscriptionParams.marketId
        );

        require(
            msg.sender == subscriptionParams.borrower,
            "Unauthorized account"
        );
        require(
            subscriptionParams.slltv < marketParams.lltv,
            "Liquidation threshold higher than market LLTV"
        );
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        isValidSubscriptionId[nbSubscriptions] = true;
        subscriptions[nbSubscriptions] = subscriptionParams;

        nbSubscriptions++;

        return nbSubscriptions - 1;
    }

    function unsubscribe(uint256 subscriptionId) public {
        require(
            msg.sender == subscriptions[subscriptionId].borrower,
            "Unauthorized account"
        );

        isValidSubscriptionId[subscriptionId] = false;
    }

    function liquidate(
        uint256 subscriptionId,
        MarketParams calldata marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) public {
        IMorpho morpho = IMorpho(MORPHO);
        require(
            isValidSubscriptionId[subscriptionId],
            "Non-valid subscription"
        );
        require(subscriptions[subscriptionId].borrower == borrower);
        require(
            Id.unwrap(subscriptions[subscriptionId].marketId) ==
                Id.unwrap(marketParams.id())
        );
        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares),
            "Inconsistent input"
        );
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        require(
            !_isHealthy(
                marketParams,
                marketParams.id(),
                borrower,
                collateralPrice,
                subscriptions[subscriptionId].slltv
            ),
            "Position is healthy"
        );

        // Compute seizedAssets or repaidShares and repaidAssets

        Market memory marketState = morpho.market(marketParams.id());
        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(
                collateralPrice,
                ORACLE_PRICE_SCALE
            );

            repaidShares = seizedAssetsQuoted
                .wDivUp(subscriptions[subscriptionId].liquidationIncentive)
                .toSharesUp(
                    marketState.totalBorrowAssets,
                    marketState.totalBorrowShares
                );
        } else {
            seizedAssets = repaidShares
                .toAssetsDown(
                    marketState.totalBorrowAssets,
                    marketState.totalBorrowShares
                )
                .wMulDown(subscriptions[subscriptionId].liquidationIncentive)
                .mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }
        uint256 repaidAssets = repaidShares.toAssetsUp(
            marketState.totalBorrowAssets,
            marketState.totalBorrowShares
        );

        // Check if liquidation is ok with close factor
        Position memory borrowerPosition = morpho.position(
            marketParams.id(),
            borrower
        );
        require(
            borrowerPosition.collateral.wMulDown(
                subscriptions[subscriptionId].closeFactor
            ) > seizedAssets,
            "Cannot liquidate more than close factor"
        );

        bytes memory callbackData = abi.encode(
            marketParams.collateralToken,
            marketParams.loanToken,
            seizedAssets,
            repaidAssets,
            borrower,
            msg.sender,
            data
        );
        morpho.repay(marketParams, 0, repaidShares, borrower, callbackData);

        isValidSubscriptionId[subscriptionId] = false;
    }

    function onMorphoRepay(
        uint256 assets,
        bytes calldata callbackData
    ) external {
        (
            MarketParams memory marketParams,
            uint256 seizedAssets,
            uint256 repaidAssets,
            address borrower,
            address liquidator,
            bytes memory data
        ) = abi.decode(
                callbackData,
                (MarketParams, uint256, uint256, address, address, bytes)
            );

        IMorpho morpho = IMorpho(MORPHO);
        morpho.withdrawCollateral(
            marketParams,
            assets,
            borrower,
            address(this)
        );

        IERC20(marketParams.collateralToken).safeTransfer(
            liquidator,
            seizedAssets
        );

        IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(assets, data);

        IERC20(marketParams.loanToken).safeTransferFrom(
            liquidator,
            address(this),
            repaidAssets
        );
        // TODO IERC20(marketParams.loanToken).safeApprove(MORPHO, repaidAssets);
    }

    function _isHealthy(
        MarketParams calldata marketParams,
        Id id,
        address borrower,
        uint256 collateralPrice,
        uint256 ltvThreshold
    ) internal view returns (bool) {
        IMorpho morpho = IMorpho(MORPHO);
        Position memory borrowerPosition = morpho.position(id, borrower);
        Market memory marketState = morpho.market(id);

        uint256 borrowed = uint256(borrowerPosition.borrowShares).toAssetsUp(
            marketState.totalBorrowAssets,
            marketState.totalBorrowShares
        );
        uint256 maxBorrow = uint256(borrowerPosition.collateral)
            .mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(ltvThreshold);

        return maxBorrow >= borrowed;
    }
}
