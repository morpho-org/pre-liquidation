// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

interface IPreLiquidationCallback {
    function onPreLiquidate(uint256 repaidAssets, bytes calldata data) external;
}
