// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISourcePortal {
    event MultiAssetVaultSet(address indexed multiAssetVaultSet);

    error SourcePortal__NotMultiAssetVault(address caller, address multiAssetVault);
    error SourcePortal__MultiAssetVaultAlreadySet(address multiAssetVault);

    function initializeMultiAssetVaultAddress(address _multiAssetVault) external;

    function mint(address _to, uint256 _amount) external;

    function burn(address _to, uint256 _amount) external;
}
