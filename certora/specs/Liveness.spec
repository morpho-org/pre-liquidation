// SPDX-License-Identifier: GPL-2.0-or-later

using PreLiquidation as preLiq;

methods {
    function preLiq.MORPHO() external returns address envfree;
}

// True when `preLiquidate` has been called.
persistent ghost bool preLiquidateCalled;

// True when `onMorphoRepay` has been called.
persistent ghost bool repayed;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (selector == sig:preLiquidate(address, uint256, uint256, bytes).selector) {
       preLiquidateCalled = true;
    } else if (selector == sig:onMorphoRepay(uint256, bytes).selector) {
       repayed = true;
    }
}

// Check that pre-liquidations happen if and only if `onMorphoRepay` is called.
rule preLiquidateRepays(method f, env e, calldataarg data) {
    require !preLiquidateCalled;
    require !repayed;
    require e.msg.sender != preLiq.MORPHO();

    if (f.selector == sig:preLiquidate(address, uint256, uint256, bytes).selector) {
       preLiquidateCalled = true;
    } else if (f.selector == sig:onMorphoRepay(uint256, bytes).selector) {
       repayed = true;
    }

    f@withrevert(e,data);

    // Avoid failing vacuity checks, either the proposition is true or the execution reverts.
    assert !lastReverted => (preLiquidateCalled <=> repayed);
}
