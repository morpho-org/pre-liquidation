# PreLiquidation

## Overview

This repository puts together different contracts to carry out liquidations on Morpho with specific parameters chosen by the borrower.
We call these user-defined Morpho Blue transactions pre-liquidations.
Borrowers can set custom pre-liquidation parameters, allowing them to specify liquidation incentive factors and close factors.
Liquidation incentive factors determine incentives given to liquidators and close factors limit the proportion of the position that can be closed during a liquidation.

The [`PreLiquidation`](./src/PreLiquidation.sol) contract serves as the endpoint for pre-liquidations using parameters chosen by borrowers.
Note that pre-liquidation must be authorized on Morpho.
Liquidators may perform pre-liquidations on a position using the `preLiquidate` entry point on a deployed `PreLiquidation` contract.
The [`PreLiquidationFactory`](./src/PreLiquidationFactory.sol) factory contract simplifies the deployment and indexing of pre-liquidation contracts.

The set of pre-liquidation parameters is composed of

- a Morpho market (`id`);
- a pre-liquidation loan-to-value (`preLltv`);
- two pre-liquidation close factor parameters (`preCF1` and `preCF2`);
- two pre-liquidation incentive factor parameters (`preLIF1` and `preLIF2`);
- a pre-liquidation oracle (`preLiquidationOracle`).

### Pre-liquidation close factor and incentive factor

The pre-liquidation close factor and the pre-liquidation incentive factor evolve linearly with the user's LTV:

- the close factor is `preCF1` when the position LTV is equal to `preLltv` and `preCF2` when the LTV is equal to `LLTV`;
- the pre-liquidation incentive factor is `preLIF1` when the position LTV equals `preLltv` and `preLIF2` when the LTV is equal to `LLTV`.

These functions are illustrated in the following figure:

<img width="1061" alt="pre-liquidation-cf-and-lif" src="https://github.com/user-attachments/assets/0c11c961-a046-4701-9063-9f6b84a6c3b2">

The two main use-cases are:

1. Using normal fixed parameters when `preLIF1 = preLIF2` and `preCF1 = preCF2`.
2. Using health dependent liquidation when either `preLIF1 < preLIF2` or `preCF1 < preCF2`, similar to a Quasi Dutch Auction (as in [Euler liquidations](https://docs-v1.euler.finance/getting-started/white-paper#liquidations)).

## Getting started

### Package installation

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

### Run tests

Run `forge test`.

## Audits

All audits are stored in the [`audits`](./audits) folder.

## License

Files in this repository are publicly available under license `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
