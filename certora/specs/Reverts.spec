// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function _.market(Id) external returns (Market memory);
}

definition exactlyOneZero(uint256 assets, uint256 shares) returns bool =
    (assets == 0 && shares != 0) || (assets != 0 && shares == 0);

invariant marketExists()
    MORPHO.market(currentContract.ID()).lastUpdate != 0;


// Check that preliquidate reverts when its inputs are not validated.
rule preLiquidateInputValidation(env e, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data) {
    preLiquidate@withrevert(e, borrower, seizedAssets, repaidShares, data);
    assert !exactlyOneZero(seizedAssets, repaidShares) => lastReverted;
}
