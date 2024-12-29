// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISourcePortal {
    error SourcePortal__NotMultiAssetVault(address caller, address multiAssetVault);

    function mint(address _to, uint256 _amount) external;

    function burn(address _to, uint256 _amount) external;
}
