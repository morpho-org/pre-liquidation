// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct PreLiquidationParams {
    uint256 preLltv;
    uint256 closeFactor;
    uint256 preLiquidationIncentive;
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

    /// @notice The Pre LLTV of the PreLiquidation contract corresponding to
    /// the maximum LTV of a position before allowing preliquidation.
    function PRE_LLTV() external view returns (uint256);
    /// @notice The close factor of the PreLiquidation contract corresponding to
    /// the maximum proportion of debt that can be pre-liquidated at once.
    function CLOSE_FACTOR() external view returns (uint256);
    /// @notice The PreLiquidation incentive of the PreLiquidation contract corresponding to
    /// the proportion of the liquidated debt value given to the liquidator in collateral token.
    function PRE_LIQUIDATION_INCENTIVE() external view returns (uint256);
    /// @notice The PreLiquidation oracle of the PreLiquidation contract corresponding to
    /// the oracle used to assess whether or not a position can be preliquidated.
    function PRE_LIQUIDATION_ORACLE() external view returns (address);

    /// @notice The loan token of the Morpho Market specific to the PreLiquidation contract.
    function LOAN_TOKEN() external view returns (address);
    /// @notice The collateral token of the Morpho Market specific to the PreLiquidation contract.
    function COLLATERAL_TOKEN() external view returns (address);
    /// @notice The oracle address of the Morpho Market specific to the PreLiquidation contract.
    function ORACLE() external view returns (address);
    /// @notice The IRM address of the Morpho Market specific to the PreLiquidation contract.
    function IRM() external view returns (address);
    /// @notice The LLTV of the Morpho Market specific to the PreLiquidation contract.
    function LLTV() external view returns (uint256);

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
