// SPDX-License-Identifier: GPL-2.0-or-later

// True when `softLiquidate` has been called.
persistent ghost bool softLiquidateCalled;

// True when `onMorphoRepay` has been called.
persistent ghost bool onMorphoRepayCalled;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:softLiquidate(address, uint256, uint256, bytes).selector) {
       softLiquidateCalled = true;
    } else if (selector == sig:onMorphoRepay(uint256, bytes).selector) {
       onMorphoRepayCalled = true;
    }
}

// Check that soft-liquidations happen if and only if `onMorphoRepay` is called.
rule softLiquidateRepays(method f, env e, calldataarg data) {

    // Set up the initial state.
    require !softLiquidateCalled;
    require !onMorphoRepayCalled;

    // Safe require because Morpho cannot send transactions.
    require e.msg.sender != currentContract.MORPHO;


    // Capture the first method call which is not performed with a CALL opcode.
    if (f.selector == sig:softLiquidate(address, uint256, uint256, bytes).selector) {
       softLiquidateCalled = true;
    } else if (f.selector == sig:onMorphoRepay(uint256, bytes).selector) {
       onMorphoRepayCalled = true;
    }

    f@withrevert(e,data);

    // Avoid failing vacuity checks, either the proposition is true or the execution reverts.
    assert !lastReverted => (softLiquidateCalled <=> onMorphoRepayCalled);
}

// Check that you can soft-liquidate non-zero tokens by passing shares.
rule canPreLiquidateByPassingShares(env e, address borrower, uint256 repaidShares, bytes data) {
    uint256 seizedAssets;
    uint256 repaidAssets;
    seizedAssets, repaidAssets = softLiquidate(e, borrower, 0, repaidShares,  data);

    satisfy seizedAssets != 0 && repaidAssets != 0;
}

// Check that you can soft-liquidate non-zero tokens by passing seized assets.
rule canPreLiquidateByPassingSeizedAssets(env e, address borrower, uint256 seizedAssets, bytes data) {
    uint256 repaidAssets;
    _, repaidAssets = softLiquidate(e, borrower, seizedAssets, 0,  data);

    satisfy repaidAssets != 0;
}
