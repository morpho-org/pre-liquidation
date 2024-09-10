// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct SubscriptionParams {
    uint256 prelltv;
    uint256 closeFactor;
    uint256 liquidationIncentive;
}

interface ILiquidationProtection {
    function subscribe(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams) external;

    function unsubscribe(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams) external;

    function liquidate(
        MarketParams calldata marketParams,
        SubscriptionParams calldata subscriptionParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external;
}
