// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IPreLiquidation, PreLiquidationParams} from "./interfaces/IPreLiquidation.sol";
import {IPreLiquidationFactory} from "./interfaces/IPreLiquidationFactory.sol";
import {IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {PreLiquidationAddressLib} from "./libraries/PreLiquidationAddressLib.sol";

import {PreLiquidation} from "./PreLiquidation.sol";

/// @title PreLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice A linear LIF and linear LCF pre-liquidation factory contract for Morpho.
contract PreLiquidationFactory is IPreLiquidationFactory {
    /* IMMUTABLE */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @notice Mapping which returns true if the address is a PreLiquidation contract created by this factory.
    mapping(address => bool) public isPreLiquidation;

    // Temporary contract creation variables.
    // Not optimized yet: make those transient.
    Id public id;
    uint256 internal preLltv;
    uint256 internal preLCF1;
    uint256 internal preLCF2;
    uint256 internal preLIF1;
    uint256 internal preLIF2;
    address internal preLiquidationOracle;

    /// @notice The pre-liquidation parameters specific currently set.
    function preLiquidationParams() external view returns (PreLiquidationParams memory) {
        return PreLiquidationParams({
            preLltv: preLltv,
            preLCF1: preLCF1,
            preLCF2: preLCF2,
            preLIF1: preLIF1,
            preLIF2: preLIF2,
            preLiquidationOracle: preLiquidationOracle
        });
    }

    /* CONSTRUCTOR */

    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    /* EXTERNAL */

    /// @notice Creates a PreLiquidation contract.
    /// @param _id The Morpho market for PreLiquidations.
    /// @param _preLiquidationParams The PreLiquidation params for the PreLiquidation contract.
    /// @dev Warning: This function will revert without data if the pre-liquidation already exists.
    function createPreLiquidation(Id _id, PreLiquidationParams calldata _preLiquidationParams)
        external
        returns (IPreLiquidation)
    {
        id = _id;
        preLltv = _preLiquidationParams.preLltv;
        preLCF1 = _preLiquidationParams.preLCF1;
        preLCF2 = _preLiquidationParams.preLCF2;
        preLIF1 = _preLiquidationParams.preLIF1;
        preLIF2 = _preLiquidationParams.preLIF2;
        preLiquidationOracle = _preLiquidationParams.preLiquidationOracle;

        bytes32 salt = PreLiquidationAddressLib.hashPreLiquidationConstructorParams(MORPHO, id, _preLiquidationParams);

        IPreLiquidation preLiquidation =
            IPreLiquidation(address(new PreLiquidation{salt: salt}()));

        emit EventsLib.CreatePreLiquidation(address(preLiquidation), id, _preLiquidationParams);

        isPreLiquidation[address(preLiquidation)] = true;

        return preLiquidation;
    }
}
