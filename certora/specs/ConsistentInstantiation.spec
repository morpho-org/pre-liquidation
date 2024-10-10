//Ensure constructor requirements.

methods {
    function _.market(PreLiquidation.Id) external => DISPATCHER(true);
}

function summaryMulDivDown(uint256 x,uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y)/d);
}

definition WAD() returns uint256 = 10^18;

definition wDivDown(uint256 x,uint256 y) returns uint256 = summaryMulDivDown(x, WAD(), y);

invariant lltvNotZero()
    0 < currentContract.LLTV
{
    preserved {
        requireInvariant preLIFNotZero();
    }
}

invariant preLltvConsistent()
    currentContract.PRE_LLTV < currentContract.LLTV
{
    preserved {
        requireInvariant preLIFNotZero();
    }
}

invariant preLCFConsistent()
    currentContract.PRE_LCF_1 <= currentContract.PRE_LCF_2
    && currentContract.PRE_LCF_1 <= WAD()
{
    preserved {
        requireInvariant preLIFNotZero();
    }
}

invariant preLIFNotZero()
    0 < currentContract.PRE_LIF_1;

invariant preLIFConsistent()
    WAD() < currentContract.PRE_LIF_1
    && currentContract.PRE_LIF_1 <= currentContract.PRE_LIF_2
    && currentContract.PRE_LIF_2 <= wDivDown(WAD(),currentContract.LLTV)
{
    preserved {
        requireInvariant lltvNotZero();
    }
}
