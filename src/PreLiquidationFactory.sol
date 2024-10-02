// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.27;

import {IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {PreLiquidation} from "./PreLiquidation.sol";
import {IPreLiquidation} from "./interfaces/IPreLiquidation.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {IPreLiquidationFactory} from "./interfaces/IPreLiquidationFactory.sol";

/// @title PreLiquidationFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice A linear LIF and linear CF pre-liquidation factory contract for Morpho.
contract PreLiquidationFactory is IPreLiquidationFactory {
    /* IMMUTABLE */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @notice Mapping which returns true if the address is a preLiquidation contract created by this factory.
    mapping(address => bool) public isPreLiquidation;

    /* CONSTRUCTOR */

    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZeroAddress());

        MORPHO = IMorpho(morpho);
    }

    /* EXTERNAL */

    /// @notice Creates a PreLiquidation contract.
    /// @param id The Morpho market for PreLiquidations.
    ///  @param preLltv the maximum LTV of a position before allowing pre-liquidation.
    ///  @param preCF1 the close factor when the position LTV is equal to preLltv.
    ///  @param preCF2 the close factor when the position LTV is equal to LLTV.
    ///  @param preLIF1 the pre-liquidation incentive factor when the position LTV is equal to preLltv.
    ///  @param preLIF2 the pre-liquidation incentive factor when the position LTV is equal to LLTV.
    ///  @param preLiquidationOracle the oracle used to assess whether or not a position can be preliquidated.
    /// @dev Warning: This function will revert without data if the pre-liquidation already exists.
    function createPreLiquidation(
        Id id,
        uint256 preLltv,
        uint256 preCF1,
        uint256 preCF2,
        uint256 preLIF1,
        uint256 preLIF2,
        address preLiquidationOracle
    ) external returns (IPreLiquidation) {
        IPreLiquidation preLiquidation = IPreLiquidation(
            address(
                new PreLiquidation{salt: 0}(
                    address(MORPHO), id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle
                )
            )
        );

        emit EventsLib.CreatePreLiquidation(
            address(preLiquidation), id, preLltv, preCF1, preCF2, preLIF1, preLIF2, preLiquidationOracle
        );

        isPreLiquidation[address(preLiquidation)] = true;

        return preLiquidation;
    }
}
