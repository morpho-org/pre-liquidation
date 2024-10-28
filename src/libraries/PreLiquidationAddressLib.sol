// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {PreLiquidation} from "../PreLiquidation.sol";
import {PreLiquidationParams} from "../interfaces/IPreLiquidation.sol";
import {Id, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

library PreLiquidationAddressLib {
    /// @dev Should be equal to keccak256(abi.encodePacked(type(PreLiquidation).creationCode))
    bytes32 internal constant INIT_CODE_HASH = 0xcd993ef7cfad420d1b706fab6105cc20ece77353481aa3ed5c0be500f3b2ddaf;

    /// @notice Computes the CREATE2 address of the pre-liquidation contract generated by the `factory`
    /// for a specific Morpho market `id` with the pre-liquidation parameters `preLiquidationParams`.
    /// @param morpho Morpho's address.
    /// @param factory PreLiquidationFactory contract address.
    /// @param id Morpho market id for the pre-liquidation contract.
    /// @param preLiquidationParams Pre-liquidation parameters.
    /// @return preLiquidationAddress The address of this pre-liquidation contract.
    function computePreLiquidationAddress(
        IMorpho morpho,
        address factory,
        Id id,
        PreLiquidationParams memory preLiquidationParams
    ) internal pure returns (address) {
        bytes32 salt = hashPreLiquidationConstructorParams(morpho, id, preLiquidationParams);
        return computePreLiquidationAddressFromSalt(factory, salt);
    }

    function computePreLiquidationAddressFromSalt(
        address factory,
        bytes32 salt)
        internal pure returns(address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(uint8(0xff), factory, salt, INIT_CODE_HASH)))));
        }

    function hashPreLiquidationConstructorParams(
        IMorpho morpho,
        Id id,
        PreLiquidationParams memory preLiquidationParams
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(morpho, id, preLiquidationParams));
    }
}