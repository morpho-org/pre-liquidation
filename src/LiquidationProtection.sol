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
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

struct SubscriptionParams {
    uint256 prelltv;
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
    IMorpho public immutable MORPHO;

    /* STORAGE */
    mapping(bytes32 => SubscriptionParams) public subscriptions;
    uint256 public nbSubscription;

    // TODO EIP-712 signature
    // TODO authorize this contract on morpho

    constructor(address morpho) {
        MORPHO = IMorpho(morpho);
    }

    function subscribe(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams)
        public
        returns (uint256)
    {
        Id marketId = marketParams.id();
        require(
            subscriptionParams.prelltv < marketParams.lltv,
            ErrorsLib.LowPreLltvError(subscriptionParams.prelltv, marketParams.lltv)
        );
        // should close factor be lower than 100% ?
        // should there be a max liquidation incentive ?

        bytes32 subscriptionId = computeSubscriptionId(msg.sender, marketId, nbSubscription);

        subscriptions[subscriptionId] = subscriptionParams;

        emit EventsLib.Subscribe(
            msg.sender,
            marketId,
            nbSubscription,
            subscriptionParams.prelltv,
            subscriptionParams.closeFactor,
            subscriptionParams.liquidationIncentive
        );

        return nbSubscription++;
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
        Id marketId = marketParams.id();
        bytes32 subscriptionId = computeSubscriptionId(borrower, marketId, subscriptionNumber);
        require(subscriptions[subscriptionId].closeFactor != 0, ErrorsLib.NonValidSubscription(subscriptionNumber));

        require(
            UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.InconsistentInput(seizedAssets, repaidShares)
        );
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        MORPHO.accrueInterest(marketParams);
        require(
            !_isHealthy(marketId, borrower, collateralPrice, subscriptions[subscriptionId].prelltv),
            ErrorsLib.HealthyPosition()
        );

        // Compute seizedAssets or repaidShares and repaidAssets
        {
            Market memory marketState = MORPHO.market(marketId);
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
        {
            Position memory borrowerPosition = MORPHO.position(marketId, borrower);
            require(
                borrowerPosition.borrowShares.wMulDown(subscriptions[subscriptionId].closeFactor) >= repaidShares,
                ErrorsLib.CloseFactorError(
                    borrowerPosition.borrowShares.wMulDown(subscriptions[subscriptionId].closeFactor), repaidShares
                )
            );
        }
        bytes memory callbackData = abi.encode(marketParams, seizedAssets, borrower, msg.sender, data);
        (uint256 repaidAssets,) = MORPHO.repay(marketParams, 0, repaidShares, borrower, callbackData);

        emit EventsLib.Liquidate(
            borrower, msg.sender, marketId, subscriptionNumber, repaidAssets, repaidShares, seizedAssets
        );
    }

    function onMorphoRepay(uint256 repaidAssets, bytes calldata callbackData) external {
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
