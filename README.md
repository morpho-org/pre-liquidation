# PreLiquidation
## Overview

The PreLiquidation is a set of contracts developed on top of Morpho on which borrowers can enable pre-liquidations, a liquidation with different guarantees.
For example, liquidations were a lower bonus is given to the liquidator or where only a part of the debt is allowed to be repaid.

There are two distinct types of contracts in this project.

- PreLiquidation whose role it to be the endpoint for pre-liquidation according to an immutable pre-liquidation settings. Borrowers can consent to pre-liquidation by authorizing the pre-liquidation contract on Morpho. Liquidators can preliquidate a position by calling `preLiquidate` on a pre-liquidation contract.
- PreLiquidationFactory whose role is to deploy various PreLiquidation contracts each with its own pre-liquidation parameters.

A pre-liquidation setting is composed of
- a morpho market (`id`)
- a pre-liquidation-loan-to-value (`preLltv`)
- two pre-liquidation close factor parameters (`preCF1` and `preCF2`)
- two pre-liquidation incentive factor parameters (`preLIF1` and `preLIF2`)
- a pre-liquidation oracle (`preLiquidationOracle`)


### How is the pre-liquidation close factor and pre-liquidation incentive factor computed ?
The pre-liquidation close factor and the pre-liquidation incentive factor evolve linearly with the user's LTV:
- the close factor is preCF1 when the position LTV equals preLLTV and preCF2 when it equals LLTV
- the liquidation incentive factor is preLIF1 at LTV=preLLTV and preLIF2 at LTV=LLTV

This computation is represented in the following graph
![LIF&CF](./img/pre-liquidation-cf-and-lif.png)

This design enable infinitely many pre-liquidation settings, the two main use-cases being
1. Using normal fixed parameters when preLIF1=preLIF2 and preCF1=preCF2.
2. Using health dependent dutch auction style liquidation (as implemented by Euler) when either preLIF1 < preLIF2 or preCF1 < preCF2.

## Getting started
### Package installation
Install [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Run tests
Run `forge test`

### Deploy a PreLiquidation contract

Any PreLiquidation contract can be deployed using the official pre-liquidation factory address

`cast send <FACTORY_ADDRESS> "createPreLiquidation(bytes32,(uint256,uint256,uint256,uint256,uint256,address))" --rpc-url <RPC_PROVIDER_URL> --interactive <MARKET_ID> <PRE_LLTV> <PRE_CF_1> <PRE_CF_2> <PRE_LIF_1> <PRE_LIF_2> <PRE_ORACLE_ADDRESS>`

Note that this command will revert if another pre-liquidation contract with the same settings already exists.

## Audits
All audits are stored in the `audits` folder.

## License
PreLiquidation is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
