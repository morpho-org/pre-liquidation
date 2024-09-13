// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, MarketParams, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct SubscriptionParams {
    uint256 prelltv;
    uint256 closeFactor;
    uint256 preLiquidationIncentive;
}

interface IPreLiquidation {
    function MORPHO() external view returns (IMorpho);
    function marketId() external view returns (Id);
    function prelltv() external view returns (uint256);
    function closeFactor() external view returns (uint256);
    function preLiquidationIncentive() external view returns (uint256);
    function lltv() external view returns (uint256);
    function collateralToken() external view returns (address);
    function loanToken() external view returns (address);
    function irm() external view returns (address);
    function oracle() external view returns (address);

    function subscriptions(address) external view returns (bool);

    function setSubscription(bool) external;

    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external;
}
