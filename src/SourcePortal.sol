// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";

contract SourcePortal is OFT, GlobalOwnerChecker, ISourcePortal {
    uint8 private constant DECIMALS = 6;
    address private constant DEAD_ADDRESS = address(1);

    address private s_multiAssetVault;

    modifier onlyMultiAssetVault() {
        if (msg.sender != s_multiAssetVault) revert SourcePortal__NotMultiAssetVault(msg.sender, s_multiAssetVault);
        _;
    }

    constructor(
        address _lzEndpoint,
        address _globalOwnable
    )
        OFT("Portal", "PORTAL", _lzEndpoint, DEAD_ADDRESS)
        Ownable(DEAD_ADDRESS)
        GlobalOwnerChecker(_globalOwnable)
    { }

    function initializeMultiAssetVaultAddress(address _multiAssetVault) external onlyOwner {
        if (s_multiAssetVault != address(0)) revert SourcePortal__MultiAssetVaultAlreadySet(s_multiAssetVault);

        s_multiAssetVault = _multiAssetVault;

        emit MultiAssetVaultSet(_multiAssetVault);
    }

    function mint(address _to, uint256 _amount) external onlyMultiAssetVault {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external onlyMultiAssetVault {
        _burn(_to, _amount);
    }

    function owner() public view override returns (address) {
        return i_globalOwnable.owner();
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
