// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {PreLiquidation} from "../../PreLiquidation.sol";
import {PreLiquidationParams} from "../../interfaces/IPreLiquidation.sol";
import {Id} from "../../../lib/morpho-blue/src/interfaces/IMorpho.sol";

library PreLiquidationAddressLib {
    /// @notice Computes the create2 address of the PreLiquidation contract generated by the `factory`
    /// for a specific Morpho market `id` with the pre-liquidation parameters `preLiquidationParams`.
    /// @param morpho Morpho contract address.
    /// @param factory PreLiquidationFactory contract address.
    /// @param id Morpho market id for the PreLiquidation contract.
    /// @param preLiquidationParams PreLiquidation parameters.
    /// @return preLiquidationAddress The address of this PreLiquidation contract.
    function computePreLiquidationAddress(
        address morpho,
        address factory,
        Id id,
        PreLiquidationParams memory preLiquidationParams
    ) internal pure returns (address) {
        bytes32 init_code_hash =
            keccak256(abi.encodePacked(type(PreLiquidation).creationCode, abi.encode(morpho, id, preLiquidationParams)));
        return address(uint160(uint256(keccak256(abi.encodePacked(uint8(0xff), factory, uint256(0), init_code_hash)))));
    }
}
