# Pre-liquidation Contract Formal Verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for the [PreLiquidation](../src/PreLiquidation.sol) contract.

## Getting Started

This project depends on two different versions of [Solidity](https://soliditylang.org/) which are required for running the verification.
The compiler binaries should be available under the following path names:

- `solc-0.8.19` for the solidity compiler version `0.8.19`, which is used for `Morpho`;
- `solc-0.8.27` for the solidity compiler version `0.8.27`, which is used for `PreLiquidation`.

To verify a specification, run the command `certoraRun Spec.conf`where `Spec.conf` is the configuration file of the matching CVL specification.
Configuration files are available in [`certora/confs`](confs).
Please ensure that `CERTORAKEY` is set up in your environment.

## Overview

The PreLiquidation contract enables Morpho borrowers to set up a safer liquidation plan on a given position, thus preventing undesired liquidations.

### Reentrancy

This is checked in [`Reentrancy.spec`](specs/Reentrancy.spec).

### Immutability

This is checked in [`Immutability.spec`](specs/Immutability.spec).

### Liveness properties

This is checked in [`Liveness.spec`](specs/Liveness.spec).

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Reentrancy.spec`](specs/Reentrancy.spec) checks that PreLiquidation is reentrancy safe by checking that the storage is never used;
- [`Immutability.spec`](specs/Immutability.spec) checks that PreLiquidation contract is immutable because it doesn't perform any delegate call;
- [`Liveness.spec`](specs/Liveness.spec) ensure that expected computations will always be performed.
  For instance, pre-liquidations will always trigger a repay operation.
  We also check that pre-liquidation can successfully be performed by passing shares to be repaid instead of the collateral ammount to be seized.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

## TODO

- [ ] Provide an overview of the specification.
- [ ] Update the verification architecture.
