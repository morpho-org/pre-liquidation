// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {ISoftLiquidation, SoftLiquidationParams} from "./interfaces/ISoftLiquidation.sol";
import {ISoftLiquidationFactory} from "./interfaces/ISoftLiquidationFactory.sol";
import {IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

import {SoftLiquidation} from "./SoftLiquidation.sol";

/// @title SoftLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice A linear LIF and linear LCF soft-liquidation factory contract for Morpho.
contract SoftLiquidationFactory is ISoftLiquidationFactory {
    /* IMMUTABLE */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @notice Mapping which returns true if the address is a SoftLiquidation contract created by this factory.
    mapping(address => bool) public isSoftLiquidation;

    /* CONSTRUCTOR */

    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    /* EXTERNAL */

    /// @notice Creates a SoftLiquidation contract.
    /// @param id The Morpho market for SoftLiquidations.
    /// @param softLiquidationParams The SoftLiquidation params for the SoftLiquidation contract.
    /// @dev Warning: This function will revert without data if the soft-liquidation already exists.
    function createSoftLiquidation(Id id, SoftLiquidationParams calldata softLiquidationParams)
        external
        returns (ISoftLiquidation)
    {
        ISoftLiquidation softLiquidation =
            ISoftLiquidation(address(new SoftLiquidation{salt: 0}(address(MORPHO), id, softLiquidationParams)));

        emit EventsLib.CreateSoftLiquidation(address(softLiquidation), id, softLiquidationParams);

        isSoftLiquidation[address(softLiquidation)] = true;

        return softLiquidation;
    }
}
