// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

/// @title ISoftLiquidationCallback
/// @notice Interface that "soft-liquidators" willing to use the soft-liquidation callback must implement.
interface ISoftLiquidationCallback {
    /// @notice Callback called when a soft-liquidation occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param repaidAssets The amount of repaid assets.
    /// @param data Arbitrary data passed to the `softLiquidate` function.
    function onSoftLiquidate(uint256 repaidAssets, bytes calldata data) external;
}
