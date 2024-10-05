# SoftLiquidation

## Overview

This repository puts together different contracts to carry out liquidations on Morpho with specific parameters chosen by the borrower.
We call these user-defined Morpho Blue transactions soft-liquidations.
Borrowers can set custom soft-liquidation parameters, allowing them to specify soft-liquidation incentive factors and soft-liquidation close factors.
Soft-liquidation incentive factors determine incentives given to liquidators and soft-liquidation close factors limit the proportion of the position that can be closed during a liquidation.

The [`SoftLiquidation`](./src/SoftLiquidation.sol) contract serves as the endpoint for soft-liquidations using parameters chosen by borrowers.
Note that soft-liquidation must be authorized on Morpho.
Liquidators may perform soft-liquidations on a position using the `softLiquidate` entry point on a deployed `SoftLiquidation` contract.
The [`SoftLiquidationFactory`](./src/SoftLiquidationFactory.sol) factory contract simplifies the deployment and indexing of soft-liquidation contracts.

The set of soft-liquidation parameters is composed of

- a Morpho market (`id`);
- a soft-liquidation loan-to-value (`softLltv`);
- two soft-liquidation close factor parameters (`softLCF1` and `softLCF2`);
- two soft-liquidation incentive factor parameters (`softLIF1` and `softLIF2`);
- a soft-liquidation oracle (`softLiquidationOracle`).

### Soft-liquidation close factor and incentive factor

The soft-liquidation close factor and the soft-liquidation incentive factor evolve linearly with the user's LTV:

- the soft-liquidation close factor is `softLCF1` when the position LTV is equal to `softLltv` and `softLCF2` when the LTV is equal to `LLTV`;
- the soft-liquidation incentive factor is `softLIF1` when the position LTV equals `softLltv` and `softLIF2` when the LTV is equal to `LLTV`.

These functions are illustrated in the following figure:

<img width="1061" alt="soft-liquidation-cf-and-lif" src="https://github.com/user-attachments/assets/0c11c961-a046-4701-9063-9f6b84a6c3b2">

The two main use-cases are:

1. Using normal fixed parameters when `softLIF1 = softLIF2` and `softLCF1 = softLCF2`.
2. Using health dependent liquidation when either `softLIF1 < softLIF2` or `softLCF1 < softLCF2`, similar to a Quasi Dutch Auction (as in [Euler liquidations](https://docs-v1.euler.finance/getting-started/white-paper#liquidations)).

### `onSoftLiquidate` callback

By calling `softLiquidate` with a smart contract that implements the `ISoftLiquidationCallback` interface, the liquidator can be called back.
More precisely, the `onSoftLiquidate` function of the liquidator's smart contract will be called after the collateral withdrawal and before the debt repayment.
This mechanism eliminates the need for a flashloan.


### SoftLiquidation Oracle

The `SoftLiquidationParams` struct includes a `softLiquidationOracle` attribute, allowing soft-liquidation using any compatible oracle.
This oracle should implement [Morpho's `IOracle` interface](https://github.com/morpho-org/morpho-blue/blob/main/src/interfaces/IOracle.sol) and adhere to the behavior specified in the documentation.
It's possible to use the corresponding market oracle or any other oracle including OEV solutions.

### SoftLiquidationAddressLib

SoftLiquidation contract addresses are generated using the CREATE2 opcode, allowing for predictable address computation depending on soft-liquidation parameters.
The [`SoftLiquidationAddressLib`](./src/libraries/periphery/SoftLiquidationAddressLib.sol) library provides a `computeSoftLiquidationAddress` function, simplifying the computation of a SoftLiquidation contract's address.

## Getting started

### Package installation

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

### Run tests

Run `forge test`.

## Audits

All audits are stored in the [`audits`](./audits) folder.

## License

Files in this repository are publicly available under license `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
