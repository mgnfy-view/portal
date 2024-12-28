// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IMultiAssetVault {
    struct Position {
        uint256 amountDeposited;
        uint256 amountMinted;
    }

    event AmountDeposited(address by, address indexed asset, uint256 indexed amount, address indexed onBehalfOf);
    event AmountWithdrawn(address indexed by, address indexed asset, uint256 indexed amount, address to);

    error MultiAssetVault__AddressZero();
    error MultiAssetVault__AssetNotWhitelisted(address asset);
    error MultiAssetVault__AmountZero();
    error MultiAssetVault__MinimumCollateralisationRatioBreached();
}
