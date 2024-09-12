// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {MarketParams, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {ILiquidationProtection, SubscriptionParams} from "./ILiquidationProtection.sol";

interface ILiquidationProtectionFactory {
    function MORPHO() external view returns (IMorpho);

    function createPreLiquidation(MarketParams calldata marketParams, SubscriptionParams calldata subscriptionParams)
        external
        returns (ILiquidationProtection liquidationProtection);
}