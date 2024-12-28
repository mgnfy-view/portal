// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAssetRegistry {
    struct AssetConfig {
        uint256 minimumCollateralisationRatio;
        uint16 liquidationRewardInBPs;
    }

    event AssetConfigSet(address indexed asset, AssetConfig indexed assetConfig);

    error AssetRegistry__AddressZero();
    error AssetRegistry__InvalidAssetConfig(address asset, AssetConfig assetConfig);

    function setAssetConfig(address _asset, AssetConfig memory _assetConfig) external;

    function isAssetWhitelisted(address _asset) external view returns (bool);

    function getAssetConfig(address _asset) external view returns (AssetConfig memory);
}
