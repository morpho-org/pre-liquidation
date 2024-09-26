// SPDX-License-Identifier: GPL-2.0-or-later
using MorphoHarness as Morpho;

methods {
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
}

invariant marketExists()
    Morpho.lastUpdate(currentContract.ID) > 0;
