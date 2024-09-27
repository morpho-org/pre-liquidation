# Morpho PreLiquidation
## Overview

The PreLiquidation is a contract implemented on top of Morpho
facilitating the liquidation of borrowers with improved guarantees.

Any user can deploy a pre-liquidation contract from the factory and authorize it on Morpho.
A pre-liquidation contract consists of
- a morpho market;
- a pre-liquidation-loan-to-value (preLLTV);
- two close factors parameters (preCF1 and preCF2);
- two pre-liquidation incentive factor (preLIF1 and preLIF2);
- a pre-liquidation oracle;

Once deployed, any user can authorize a pre-liquidation contract and pre-liquidators will be able to pre-liquidate the user position on the corresponding market according to the pre-liquidation parameters.

## Getting started
Run `forge test` to run tests.
## Audits
TBD

## License
PreLiquidation is licensed under `GPL-2.0-or-later`
