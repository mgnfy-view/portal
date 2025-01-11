// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { PythUtils } from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

import { IPythOracle } from "./interfaces/IPythOracle.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";
import { Math } from "./utils/Math.sol";

/// @title PythOracle.
/// @author mgnfy-view.
/// @notice This contract is used by the `MultiAssetVault` to query prices of whitelisted assets
/// from the `AssetRegistry` with 18 target decimal.
contract PythOracle is GlobalOwnerChecker, IPythOracle {
    /// @dev The decimals the returned price should be represented in.
    uint8 private constant TARGET_DECIMALS = 18;
    /// @dev The max allowed confidence value as a percentage of price in bps. If the confidence
    /// value is too high, it implies uncertainty in the reported price.
    uint16 private constant MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS = 1000;

    /// @dev The on-chain pyth contract to query the prices from.
    IPyth private immutable i_pyth;
    /// @dev Oracle configuration which stores the price feed id and the staleness threshold
    /// per asset.
    mapping(address asset => OracleConfig oracleConfig) private s_assetToOracleConfig;

    /// @notice Sets the golbal ownable and pyth contracts.
    /// @param _globalOwnable The address of the `GlobalOwnable` contract to retrieve the current
    /// global owner.
    /// @param _pyth The on-chain pyth contract to query the prices from.
    constructor(address _globalOwnable, address _pyth) GlobalOwnerChecker(_globalOwnable) {
        if (_pyth == address(0)) revert PythOracle__AddressZero();

        i_pyth = IPyth(_pyth);
    }

    /// @notice Allows the global owner to set the oracle config for an asset.
    /// @dev Once a config is set, it can not be removed, only modified.
    /// @param _asset The asset address.
    /// @param _oracleConfig The configuration parameters for the oracle.
    function setOracleConfig(address _asset, OracleConfig memory _oracleConfig) external onlyGlobalOwner {
        if (_asset == address(0)) revert PythOracle__AddressZero();
        if (_oracleConfig.priceFeedId == 0 || _oracleConfig.stalenessThreshold == 0) {
            revert PythOracle__InvalidOracleConfig(_asset, _oracleConfig);
        }

        s_assetToOracleConfig[_asset] = _oracleConfig;

        emit OracleConfigSet(_asset, _oracleConfig);
    }

    /// @notice Gets the price of an asset in 18 decimals representation.
    /// @param _asset The asset address.
    /// @return The price of an asset in 18 decimals representation.
    function getPriceInUsd(address _asset) external view returns (uint256) {
        OracleConfig memory oracleConfig = s_assetToOracleConfig[_asset];
        if (oracleConfig.priceFeedId == 0) revert PythOracle__OracleNotSet(_asset);

        PythStructs.Price memory priceStruct =
            i_pyth.getPriceNoOlderThan(oracleConfig.priceFeedId, oracleConfig.stalenessThreshold);
        uint256 priceInTargetDecimals = PythUtils.convertToUint(priceStruct.price, priceStruct.expo, TARGET_DECIMALS);
        uint256 confidenceInTargetDecimals =
            PythUtils.convertToUint(int64(priceStruct.conf), priceStruct.expo, TARGET_DECIMALS);

        if (
            confidenceInTargetDecimals
                > Math.applyPercentage(priceInTargetDecimals, MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS)
        ) revert PythOracle__ConfidenceThresholdBreached(confidenceInTargetDecimals, priceInTargetDecimals);

        return priceInTargetDecimals;
    }

    /// @notice Gets the target decimals to represent the prices in.
    /// @return The target decimals to represent the prices in.
    function getTargetDecimals() external pure returns (uint8) {
        return TARGET_DECIMALS;
    }

    /// @notice Gets the max allowed confidence as a percentage of price in bps.
    /// @return The max allowed confidence as a percentage of price in bps.
    function getMaxAllowedConfidenceAsAPercentageOfPriceInBPs() external pure returns (uint16) {
        return MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS;
    }

    /// @notice Gets the pyth contract address.
    /// @return The pyth contract address.
    function getPyth() external view returns (address) {
        return address(i_pyth);
    }

    /// @notice Gets the oracle config for a given asset.
    /// @param _asset The asset address.
    function getOracleConfig(address _asset) external view returns (OracleConfig memory) {
        return s_assetToOracleConfig[_asset];
    }
}
