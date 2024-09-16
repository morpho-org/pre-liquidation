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

    function marketId() external view returns (Id);

    function preLltv() external view returns (uint256);
    function closeFactor() external view returns (uint256);
    function preLiquidationIncentive() external view returns (uint256);

    function loanToken() external view returns (address);
    function collateralToken() external view returns (address);
    function oracle() external view returns (address);
    function irm() external view returns (address);
    function lltv() external view returns (uint256);

    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external;
}
