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
    /// @notice Morpho's address.
    function MORPHO() external view returns (IMorpho);

    /// @notice The id of the Morpho Market specific to the PreLiquidation contract.
    function ID() external view returns (Id);

    /// @notice The Morpho market parameters specific to the PreLiquidation contract.
    function getMarketParams() external returns (MarketParams memory);

    /// @notice The pre-liquidation parameters specific to the PreLiquidation contract.
    function getPreLiquidationParams() external view returns (PreLiquidationParams memory);

    /// @notice Preliquidates the given `repaidShares of debt asset or seize the given `seizedAssets`of collateral on the
    /// contract's Morpho market of the given `borrower`'s position, optionally calling back the caller's `onPreLiquidate`
    /// function with the given `data`.
    /// @dev Either `seizedAssets`or `repaidShares` should be zero.
    /// @param borrower The owner of the position.
    /// @param seizedAssets The amount of collateral to seize.
    /// @param repaidShares The amount of shares to repay.
    /// @param data Arbitrary data to pass to the `onPreLiquidate` callback. Pass empty data if not needed.
    function preLiquidate(address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external;
}
