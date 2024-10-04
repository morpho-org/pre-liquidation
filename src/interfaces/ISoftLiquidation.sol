// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @notice The soft-liquidation parameters are:
///  - softLltv, the maximum LTV of a position before allowing soft-liquidation.
///  - softLCF1, the soft-liquidation close factor when the position LTV is equal to softLltv.
///  - softLCF2, the soft-liquidation close factor when the position LTV is equal to LLTV.
///  - softLIF1, the soft-liquidation incentive factor when the position LTV is equal to softLltv.
///  - softLIF2, the soft-liquidation incentive factor when the position LTV is equal to LLTV.
///  - softLiquidationOracle, the oracle used to assess whether or not a position can be softliquidated.
struct SoftLiquidationParams {
    uint256 softLltv;
    uint256 softLCF1;
    uint256 softLCF2;
    uint256 softLIF1;
    uint256 softLIF2;
    address softLiquidationOracle;
}

interface ISoftLiquidation {
    function MORPHO() external view returns (IMorpho);

    function ID() external view returns (Id);

    function marketParams() external returns (MarketParams memory);

    function softLiquidationParams() external view returns (SoftLiquidationParams memory);

    function softLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data)
        external
        returns (uint256, uint256);
}
