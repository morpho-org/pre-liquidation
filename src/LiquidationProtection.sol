// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

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
import {EventsLib, SubscriptionParams} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

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
    IMorpho public immutable MORPHO;

    /* STORAGE */
    mapping(bytes32 => bool) public subscriptions;

    constructor(address morpho) {
        MORPHO = IMorpho(morpho);
    }

    function subscribe(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams) external {
        require(
            subscriptionParams.prelltv < marketParams.lltv,
            ErrorsLib.PreLltvTooHigh(subscriptionParams.prelltv, marketParams.lltv)
        );
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        Id marketId = marketParams.id();
        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId, subscriptionParams);

        subscriptions[subscriptionId] = true;

        emit EventsLib.Subscribe(msg.sender, marketId, subscriptionParams);
    }

    function unsubscribe(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams) external {
        Id marketId = marketParams.id();
        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId, subscriptionParams);

        subscriptions[subscriptionId] = false;

        emit EventsLib.Unsubscribe(msg.sender, marketId, subscriptionParams);
    }

    function liquidate(
        MarketParams calldata marketParams,
        SubscriptionParams calldata subscriptionParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external {
        Id marketId = marketParams.id();
        bytes32 subscriptionId = computeSubscriptionId(borrower, marketId, subscriptionNumber);
        require(subscriptions[subscriptionId].closeFactor != 0, ErrorsLib.InvalidSubscription(subscriptionNumber));

        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput(seizedAssets, repaidShares)
        );
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        MORPHO.accrueInterest(marketParams);
        require(
            !_isHealthy(marketId, borrower, collateralPrice, subscriptionParams.prelltv), ErrorsLib.HealthyPosition()
        );

        {
            // Compute seizedAssets or repaidShares and repaidAssets
            Market memory market = MORPHO.market(marketId);
            uint256 liquidationIncentive = subscriptionParams.liquidationIncentive;
            if (seizedAssets > 0) {
                uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

                repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentive).toSharesUp(
                    market.totalBorrowAssets, market.totalBorrowShares
                );
            } else {
                seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                    liquidationIncentive
                ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
                seizedAssets = repaidShares.toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares).wMulDown(
                    liquidationIncentive
                ).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
            }

            // Check if liquidation is ok with close factor
            Position memory borrowerPosition = MORPHO.position(marketId, borrower);
            require(
                borrowerPosition.borrowShares.wMulDown(subscriptions[subscriptionId].closeFactor) >= repaidShares,
                ErrorsLib.LiquidationTooLarge(
                    borrowerPosition.borrowShares.wMulDown(subscriptions[subscriptionId].closeFactor), repaidShares
                )
            );
        }

        bytes memory callbackData = abi.encode(marketParams, seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.Liquidate(
            borrower, marketId, subscriptionParams, msg.sender, repaidAssets, repaidShares, seizedAssets
        );
    }

    function onMorphoRepay(uint256 assets, bytes calldata callbackData) external {
        require(msg.sender == address(MORPHO), ErrorsLib.NotMorpho(msg.sender));
        (
            MarketParams memory marketParams,
            uint256 seizedAssets,
            address borrower,
            address liquidator,
            bytes memory data
        ) = abi.decode(callbackData, (MarketParams, uint256, address, address, bytes));

        MORPHO.withdrawCollateral(marketParams, seizedAssets, borrower, liquidator);

        if (data.length > 0) {
            IMorphoLiquidateCallback(liquidator).onMorphoLiquidate(repaidAssets, data);
        }

        ERC20(marketParams.loanToken).safeTransferFrom(liquidator, address(this), repaidAssets);

        ERC20(marketParams.loanToken).safeApprove(address(MORPHO), repaidAssets);
    }

    function computeSubscriptionId(address borrower, Id marketId, SubscriptionParams memory subscriptionParams)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(borrower, marketId, subscriptionParams));
    }

    function _isHealthy(Id id, address borrower, uint256 collateralPrice, uint256 ltvThreshold)
        internal
        view
        returns (bool)
    {
        Position memory borrowerPosition = MORPHO.position(id, borrower);
        Market memory market = MORPHO.market(id);

        uint256 borrowed =
            uint256(borrowerPosition.borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        uint256 maxBorrow =
            uint256(borrowerPosition.collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(ltvThreshold);

        return maxBorrow >= borrowed;
    }
}
