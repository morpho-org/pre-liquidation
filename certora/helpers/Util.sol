// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {Id, MarketParams} from "src/PreLiquidation.sol";

import {MarketParamsLib} from "lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract Util {
    using MarketParamsLib for MarketParams;

    function libId(MarketParams memory marketParams) external pure returns (Id) {
        return marketParams.id();
    }
}
