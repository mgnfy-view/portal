// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";

contract AssetRegistry is GlobalOwnerChecker, IAssetRegistry {
    mapping(address asset => AssetConfig config) private s_assetConfig;

    constructor(address _globalOwnable) GlobalOwnerChecker(_globalOwnable) { }

    function setAssetConfig(address _asset, AssetConfig memory _assetConfig) external onlyGlobalOwner {
        if (_asset == address(0)) revert AssetRegistry__AddressZero();
        if (_assetConfig.minimumCollateralisationRatio == 0 || _assetConfig.liquidationRewardInBPs == 0) {
            revert AssetRegistry__InvalidAssetConfig(_asset, _assetConfig);
        }

        s_assetConfig[_asset] = _assetConfig;

        emit AssetConfigSet(_asset, _assetConfig);
    }

    function isAssetWhitelisted(address _asset) external view returns (bool) {
        return s_assetConfig[_asset].minimumCollateralisationRatio != 0;
    }

    function getAssetConfig(address _asset) external view returns (AssetConfig memory) {
        return s_assetConfig[_asset];
    }
}
