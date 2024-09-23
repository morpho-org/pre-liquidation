# Pre-liquidation Contract Formal Verification

This folder contains the
[CVL](https://docs.certora.com/en/latest/docs/cvl/index.html)
specification and verification setup for the
[pre-liquidation](../src/PreLiquidation.sol) contract using the
[Certora Prover](https://www.certora.com/).

## Getting Started

This project depends on two different versions of
[Solidity](https://soliditylang.org/) which are required for running
the verification. The compiler binaries should be available under the
following path names:

  - `solc-0.8.19` for the solidity compiler version `0.8.19`, which is
    used for `Morpho`;
  - `solc-0.8.27` for the solidity compiler version `0.8.27`, which is
    used for `PreLiquidation`.

### Installing the Certora Prover

The Certora CLI can be installed by running `python3 -m pip3 install
certora-cli`. Detailed installation instructions can be found on
Certora's official
[documentation](https://docs.certora.com/en/latest/docs/user-guide/install.html).

To verifying a specification, run the command `certoraRun Spec.conf`
where `Spec.conf` is the configuration file of the matching CVL
specification. Configuration files are available in
[`certora/conf`](./confs). Please ensure that `CERTORA_KEY` is set up
in your environment.

## Overview

The PreLiquidation contract enables Morpho Blue borrowers to set up a
safer liquidation plan on a given position, thus preventing undesired
liquidations.

### Reentrancy

This is checked in [`Reentrancy.spec`](specs/Reentrancy.spec).

### Immutability

This is checked in [`Immutability.spec`](specs/Immutability.spec).

## Verification architecture

### Folders and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`Reentrancy.spec`](specs/Reentrancy.spec) checks that
  PreLiquidation is reentrancy safe by checking that the storage is never
  used.

- [`Immutability.spec`](specs/Immutability.spec) checks that
  PreLiquidation's storage is safe by checking that the storage is never
  changed by a delegate call..

The [`certora/confs`](confs) folder contains a configuration file for
each corresponding specification file.

The [`certora/helpers`](helpers) folder contains helper contracts that
enable the verification of PreLiquidation. Notably, this allows
handling the fact that library functions should be called from a
contract to be verified independently, and it allows defining needed
getters.

## TODO

- [ ] Provide an overview of the specification.
- [ ] Update the verification architecture.
