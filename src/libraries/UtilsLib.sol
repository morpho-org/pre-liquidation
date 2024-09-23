// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SALT} from "../libraries/ConstantsLib.sol";
import {PreLiquidation} from "../PreLiquidation.sol";
import {PreLiquidationParams} from "../interfaces/IPreLiquidation.sol";
import {Id} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title UtilsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing helpers.
/// @dev Inspired by https://github.com/morpho-org/morpho-utils.

library UtilsLib {
    function computePreLiquidationAddress(
        Id id,
        PreLiquidationParams memory preLiquidationParams,
        address morpho,
        address factory
    ) internal pure returns (address preLiquidationAddress) {
        bytes32 init_code_hash =
            keccak256(abi.encodePacked(type(PreLiquidation).creationCode, abi.encode(id, preLiquidationParams, morpho)));
        preLiquidationAddress =
            address(uint160(uint256(keccak256(abi.encodePacked(uint8(0xff), factory, SALT, init_code_hash)))));
    }
}
