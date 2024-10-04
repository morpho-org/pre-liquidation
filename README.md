# PreLiquidation

## Overview

This repository puts together different contracts to carry out liquidations on Morpho with specific parameters chosen by the borrower.
We call these user-defined Morpho Blue transactions pre-liquidations.
Borrowers can set custom pre-liquidation parameters, allowing them to specify pre-liquidation incentive factors and pre-liquidation close factors.
Pre-liquidation incentive factors determine incentives given to liquidators and pre-liquidation close factors limit the proportion of the position that can be closed during a liquidation.

The [`PreLiquidation`](./src/PreLiquidation.sol) contract serves as the endpoint for pre-liquidations using parameters chosen by borrowers.
Note that pre-liquidation must be authorized on Morpho.
Liquidators may perform pre-liquidations on a position using the `preLiquidate` entry point on a deployed `PreLiquidation` contract.
The [`PreLiquidationFactory`](./src/PreLiquidationFactory.sol) factory contract simplifies the deployment and indexing of pre-liquidation contracts.

The set of pre-liquidation parameters is composed of

- a Morpho market (`id`);
- a pre-liquidation loan-to-value (`preLltv`);
- two pre-liquidation close factor parameters (`preLCF1` and `preLCF2`);
- two pre-liquidation incentive factor parameters (`preLIF1` and `preLIF2`);
- a pre-liquidation oracle (`preLiquidationOracle`).

### Pre-liquidation close factor and incentive factor

The pre-liquidation close factor and the pre-liquidation incentive factor evolve linearly with the user's LTV:

- the pre-liquidation close factor is `preLCF1` when the position LTV is equal to `preLltv` and `preLCF2` when the LTV is equal to `LLTV`;
- the pre-liquidation incentive factor is `preLIF1` when the position LTV equals `preLltv` and `preLIF2` when the LTV is equal to `LLTV`.

These functions are illustrated in the following figure:

<img width="1061" alt="pre-liquidation-cf-and-lif" src="https://github.com/user-attachments/assets/0c11c961-a046-4701-9063-9f6b84a6c3b2">

The two main use-cases are:

1. Using normal fixed parameters when `preLIF1 = preLIF2` and `preLCF1 = preLCF2`.
2. Using health dependent liquidation when either `preLIF1 < preLIF2` or `preLCF1 < preLCF2`, similar to a Quasi Dutch Auction (as in [Euler liquidations](https://docs-v1.euler.finance/getting-started/white-paper#liquidations)).


### Pre-liquidation parameters restrictions

The PreLiquidation smart-contract enforces:
1. preLltv < LLTV;
2. preLCF1 <= preLCF2;
3. WAD <= preLIF1 <= preLIF2.

Note that `preLCF1 <= WAD` and `preLCF1 <= WAD` is not mandatory.
Indeed without this, the close factor can reach 100% when the position LTV is less than LLTV allowing additionnal pre-liquidation close factor configurations.
A pre-liquidation close factor higher than 100% means that the whole position is liquidatable.

### `onPreLiquidate` callback

By calling `preLiquidate` with a smart contract that implements the `IPreLiquidationCallback` interface, the liquidator can be called back.
More precisely, the `onPreLiquidate` function of the liquidator's smart contract will be called after the collateral withdrawal and before the debt repayment.
This mechanism eliminates the need for a flashloan.


### PreLiquidation Oracle

The `PreLiquidationParams` struct includes a `preLiquidationOracle` attribute, allowing pre-liquidation using any compatible oracle.
This oracle should implement [Morpho's `IOracle` interface](https://github.com/morpho-org/morpho-blue/blob/main/src/interfaces/IOracle.sol) and adhere to the behavior specified in the documentation.
It's possible to use the corresponding market oracle or any other oracle including OEV solutions.

### PreLiquidationAddressLib

PreLiquidation contract addresses are generated using the CREATE2 opcode, allowing for predictable address computation depending on pre-liquidation parameters.
The [`PreLiquidationAddressLib`](./src/libraries/periphery/PreLiquidationAddressLib.sol) library provides a `computePreLiquidationAddress` function, simplifying the computation of a PreLiquidation contract's address.

## Getting started

### Package installation

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

### Run tests

Run `forge test`.

## Audits

All audits are stored in the [`audits`](./audits) folder.

## License

Files in this repository are publicly available under license `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
