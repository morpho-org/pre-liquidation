// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {PreLiquidation, Id, Market, Position, PreLiquidationParams} from "../../src/PreLiquidation.sol";
import {IMorphoStaticTyping} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

contract Wallet {
    PreLiquidation immutable preLiq;

    constructor(PreLiquidation p) {
        preLiq = p;
    }

    function preLiquidateCall(bytes calldata args) external {
        (address borrower, uint256 seizedAssets, uint256 repaidShares, bytes memory data) =
            abi.decode(args, (address, uint256, uint256, bytes));
        preLiq.preLiquidate(borrower, seizedAssets, repaidShares, data);
    }

    function onMorphoRepayCall(bytes calldata args) external {
        (uint256 repaidAssets, bytes memory data) = abi.decode(args, (uint256, bytes));
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
