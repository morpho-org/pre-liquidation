// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {MarketParams, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct SubscriptionParams {
    uint256 prelltv;
    uint256 closeFactor;
    uint256 preLiquidationIncentive;
}

interface ILiquidationProtection {
    function MORPHO() external view returns (IMorpho);

    function subscriptions(address) external view returns (bool);

    function subscribe() external;

    function unsubscribe() external;

    function liquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external;
}
