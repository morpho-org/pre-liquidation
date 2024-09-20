// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

/// @title IPreLiquidationCallback
/// @notice Interface that preliquidators willing to use `preliquidate's callback must implement.
interface IPreLiquidationCallback {
    /// @notice Callback called when a preLiquidation occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param repaidAssets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `preLiquidate` function.
    function onPreLiquidate(uint256 repaidAssets, bytes calldata data) external;
}
