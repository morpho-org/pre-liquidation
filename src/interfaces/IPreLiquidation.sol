// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho, MarketParams} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @notice The pre-liquidation parameters are:
///  - preLltv, the maximum LTV of a position before allowing pre-liquidation.
///  - closeFactor, the maximum proportion of debt that can be pre-liquidated at once.
///  - preLiquidationIncentiveFactor, the factor used to multiply repaid debt value to get the seized collateral value in a pre-liquidation.
///  - preLiquidationOracle, the oracle used to assess whether or not a position can be preliquidated.
struct PreLiquidationParams {
    uint256 preLltv;
    uint256 closeFactor;
    uint256 preLiquidationIncentiveFactor;
    address preLiquidationOracle;
}

/// @title IPreLiquidation
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of PreLiquidation.
interface IPreLiquidation {

    function MORPHO() external view returns (IMorpho);


    function ID() external view returns (Id);


    function marketParams() external returns (MarketParams memory);


    function preLiquidationParams() external view returns (PreLiquidationParams memory);


    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external;
}
