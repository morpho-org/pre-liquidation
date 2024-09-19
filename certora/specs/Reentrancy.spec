// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function _.accrueInterest(PreLiquidationHarness.MarketParams) external => voidSummary() expect void;
    function _.repay(PreLiquidationHarness.MarketParams, uint256, uint256, address, bytes) external =>
      uintPairSummary() expect (uint256, uint256);
    function _.withdrawCollateral(PreLiquidationHarness.MarketParams, uint256, address, address) external
      => voidSummary() expect void;
}

// True when storage has been accessed with either a SSTORE or a SLOAD.
persistent ghost bool hasAccessedStorage;
// True when a CALL has been done after storage has been accessed.
persistent ghost bool hasCallAfterAccessingStorage;
// True when storage has been accessed, after which an external call is made, followed by accessing storage again.
persistent ghost bool hasReentrancyUnsafeCall;
// True for reentrant-safe functions of Morpho Blue are being called.
persistent ghost bool ignoredCall;

function voidSummary() {
    ignoredCall = true;
}

function uintPairSummary() returns (uint256, uint256) {
    ignoredCall = true;
    uint256 firstValue;
    uint256 secondValue;
    return (firstValue, secondValue);
}

hook ALL_SSTORE(uint loc, uint v) {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook ALL_SLOAD(uint loc) uint v {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (ignoredCall) {
        // Ignore calls to tokens and Morpho markets as they are trusted (they have gone through a timelock).
        ignoredCall = false;
    } else {
        hasCallAfterAccessingStorage = hasAccessedStorage;
    }
}

// Check that no function is accessing storage, then making an external CALL other than to the IRM, and accessing storage again.
rule reentrancySafe(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !ignoredCall && !hasAccessedStorage && !hasCallAfterAccessingStorage && !hasReentrancyUnsafeCall;
    f(e,data);
    assert !hasReentrancyUnsafeCall;
}
