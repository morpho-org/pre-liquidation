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
    Id marketId;
    address borrower;
    bool isValid;
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
    IMorpho immutable MORPHO;

    /* STORAGE */
    mapping(bytes32 => SubscriptionParams) public subscriptions;
    uint256 public nbSubscription;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho
    // TODO potential gas opti (keeping marketparams in SubscriptionParams instead of Id?)

    constructor(address morpho) {
        MORPHO = IMorpho(morpho);
    }

    function subscribe(Id marketId, SubscriptionParams calldata subscriptionParams) public returns (uint256) {
        MarketParams memory marketParams = MORPHO.idToMarketParams(marketId);

        require(subscriptionParams.slltv < marketParams.lltv, "Liquidation threshold higher than market LLTV");
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId, nbSubscription);

        subscriptions[subscriptionId] = subscriptionParams;

        emit EventsLib.Subscribe(
            msg.sender,
            marketId,
            nbSubscription,
            subscriptionParams.slltv,
            subscriptionParams.closeFactor,
            subscriptionParams.liquidationIncentive
        );
        nbSubscription++;

        return nbSubscription - 1;
    }

    function unsubscribe(Id marketId, uint256 subscriptionNumber) public {
        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId, subscriptionNumber);

        delete subscriptions[subscriptionId];

        emit EventsLib.Unsubscribe(msg.sender, marketId, subscriptionNumber);
    }

    function liquidate(
        uint256 subscriptionNumber,
        MarketParams calldata marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) public {
        bytes32 subscriptionId = computeSubscriptionId(borrower, marketParams.id(), subscriptionNumber);

        require(subscriptions[subscriptionId].closeFactor != 0, "Non-valid subscription");

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
                seizedAssets = repaidShares.toAssetsDown(marketState.totalBorrowAssets, marketState.totalBorrowShares)
                    .wMulDown(liquidationIncentive).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }
        }

        // Check if liquidation is ok with close factor
        Position memory borrowerPosition = MORPHO.position(marketParams.id(), borrower);
        require(
            borrowerPosition.collateral.wMulDown(subscriptions[subscriptionId].closeFactor) > seizedAssets,
            "Cannot liquidate more than close factor"
        );

        bytes memory callbackData = abi.encode(marketParams, seizedAssets, borrower, msg.sender, data);
        (uint256 assets,) = MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.Liquidate(subscriptionNumber, assets, repaidShares, seizedAssets);
    }

    function onMorphoRepay(uint256 assets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), "Not Morpho");
        (
            MarketParams memory marketParams,
            uint256 seizedAssets,
            address borrower,
            address liquidator,
            bytes memory data
        ) = abi.decode(callbackData, (MarketParams, uint256, address, address, bytes));

        MORPHO.withdrawCollateral(marketParams, seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            IMorphoLiquidateCallback(liquidator).onMorphoLiquidate(assets, data);
        }

        ERC20(marketParams.loanToken).safeTransferFrom(liquidator, address(this), assets);

        ERC20(marketParams.loanToken).safeApprove(address(MORPHO), assets);
    }

    function computeSubscriptionId(address borrower, Id marketId, uint256 subscriptionNumber)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(borrower, marketId, subscriptionNumber));
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
