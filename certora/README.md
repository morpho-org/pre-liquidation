# Pre-liquidation contract formal verification

This folder contains the [CVL](https://docs.certora.com/en/latest/docs/cvl/index.html) specification and verification setup for the [PreLiquidation](../src/PreLiquidation.sol) contract.

## Getting started

This project depends on two different versions of [Solidity](https://soliditylang.org/) which are required for running the verification.
The compiler binaries should be available in the paths:

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

### Reverts

This is checked in [`Reverts.spec`](specs/Reverts.spec) and [`MarketExists.spec`](specs/MarketExists.spec)

### Consistent instantiation

This is checked in [`ConsistentInstantiation.spec`](specs/ConsistentInstantiation.spec).

### Liveness properties

This is checked in [`Liveness.spec`](specs/Liveness.spec).

### Safe math

This is checked in [`SafeMath.spec`](specs/SafeMath.spec).

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Reentrancy.spec`](specs/Reentrancy.spec) checks that PreLiquidation is reentrancy safe by checking that the storage is never used;
- [`Immutability.spec`](specs/Immutability.spec) checks that PreLiquidation contract is immutable because it doesn't perform any delegate call;
- [`Liveness.spec`](specs/Liveness.spec) ensure that expected computations will always be performed.
  For instance, pre-liquidations will always trigger a repay operation.
  We also check that pre-liquidation can successfully be performed by passing shares to be repaid instead of the collateral amount to be seized.
- [`Reverts.spec`](specs/Reverts.spec) checks the conditions for reverts and that inputs are correctly validated.
- [`ConsistentInstantiation.spec`](specs/ConsistentInstantiation.spec) checks the conditions for reverts are met in PreLiquidation constructor.
- [`MarketExists.spec`](specs/MarketExists.spec) checks that PreLiquidations can be instantiated only if the target market exists;
- [`SafeMath.spec`](specs/SafeMath.spec) checks that PreLiquidations mathematical operation are safe.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.
