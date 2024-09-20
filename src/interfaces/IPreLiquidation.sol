// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, MarketParams, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct PreLiquidationParams {
    uint256 preLltv;
    uint256 closeFactor;
    uint256 preLiquidationIncentive;
}

interface IPreLiquidation {
    function MORPHO() external view returns (IMorpho);

    function ID() external view returns (Id);

    function PRE_LLTV() external view returns (uint256);
    function CLOSE_FACTOR() external view returns (uint256);
    function PRE_LIQUIDATION_INCENTIVE() external view returns (uint256);

    function preLiquidate(
        MarketParams memory,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external;
}
