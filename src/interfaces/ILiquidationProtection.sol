// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >= 0.5.0;

struct SubscriptionParams {
    uint256 prelltv;
    uint256 closeFactor;
    uint256 liquidationIncentive;
}

// TODO: add ILiquidationProtection interface
