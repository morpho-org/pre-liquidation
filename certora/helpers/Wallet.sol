// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {PreLiquidation, Id, Market, Position, PreLiquidationParams} from "../../src/PreLiquidation.sol";
import {IMorphoStaticTyping} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

contract Wallet {
    PreLiquidation immutable preLiq;

    constructor(PreLiquidation p) {
        preLiq = p;
    }

    function preLiquidateCall(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes memory data)
        external
    {
        preLiq.preLiquidate(borrower, seizedAssets, repaidShares, data);
    }

    function onMorphoRepayCall(uint256 repaidAssets, bytes memory data) external {
        preLiq.onMorphoRepay(repaidAssets, data);
    }

    function marketParamsCall() external view {
        preLiq.marketParams();
    }

    function preLiquidationParamsCall() external view {
        preLiq.preLiquidationParams();
    }

    function morphoCall() external view {
        preLiq.MORPHO();
    }

    function idCall() external view {
        preLiq.ID();
    }
}
