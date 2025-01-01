// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";

/// @title AssetRegistry.
/// @author mgnfy-view.
/// @notice This contract tracks all whitelisted assets that can be used as collateral to mint
/// the portal stablecoin.
contract AssetRegistry is GlobalOwnerChecker, IAssetRegistry {
    /// @dev A mapping from the whitelisted asset to its config, which includes the
    /// minimum collateralisation ratio, and liquidation reward in BPs.
    mapping(address asset => AssetConfig config) private s_assetConfig;

    /// @notice Initializes the global ownable contract's address to query the current global
    /// owner.
    /// @param _globalOwnable The address of the global ownable contract.
    constructor(address _globalOwnable) GlobalOwnerChecker(_globalOwnable) { }

    /// @notice Allows the current global owner to set the config for an asset, which includes the
    /// minimum collateralisation ratio, and liquidation reward in BPs.
    /// @dev Setting the asset config indirectly whitelists the asset as a valid collateral type.
    /// @dev Once set, the asset cannot be removed, so this function must be dealt with care.
    /// @dev This function can also be used to modify the asset config.
    /// @param _asset The asset's address.
    /// @param _assetConfig The asset config.
    function setAssetConfig(address _asset, AssetConfig memory _assetConfig) external onlyGlobalOwner {
        if (_asset == address(0)) revert AssetRegistry__AddressZero();
        if (_assetConfig.minimumCollateralisationRatio == 0 || _assetConfig.liquidationRewardInBPs == 0) {
            revert AssetRegistry__InvalidAssetConfig(_asset, _assetConfig);
        }

        s_assetConfig[_asset] = _assetConfig;

        emit AssetConfigSet(_asset, _assetConfig);
    }

    /// @notice Checks if the asset is whitelisted or not.
    /// @param _asset The asset's address.
    /// @return A boolean indicating whether the asset is whitelisted or not.
    function isAssetWhitelisted(address _asset) external view returns (bool) {
        return s_assetConfig[_asset].minimumCollateralisationRatio != 0;
    }

    /// @notice Gets the asset config.
    /// @param _asset The asset's address.
    /// @return The associated config for an asset.
    function getAssetConfig(address _asset) external view returns (AssetConfig memory) {
        return s_assetConfig[_asset];
    }
}
