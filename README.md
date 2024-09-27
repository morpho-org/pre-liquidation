# Morpho PreLiquidation
## Overview

The PreLiquidation contract is a contract implemented on top of Morpho
allowing borrowers to be liquidated with better conditions.

Any user can deploy a pre-liquidation contract from the factory and authorize it on Morpho.
A pre-liquidation contract is defined by
- A morpho market
- A pre-liquidation-loan-to-value (preLLTV)
- Two close factors parameters (closeFactor1 and closeFactor2)
- Two pre-liquidation incentive factor (preLIF1 and preLIF2)
- A pre-liquidation oracle

Once deployed, any user can authorize a pre-liquidation contract and pre-liquidators will be able to pre-liquidate the user position on the corresponding market according to the pre-liquidation parameters.

## Getting started

## Audits
TBD

## License
PreLiquidation is licensed under `GPL-2.0-or-later`
