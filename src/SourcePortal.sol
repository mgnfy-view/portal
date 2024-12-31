// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";

contract SourcePortal is OFT, GlobalOwnerChecker, ISourcePortal {
    uint8 private constant DECIMALS = 6;

    address private immutable i_multiAssetVault;

    modifier onlyMultiAssetVault() {
        if (msg.sender != i_multiAssetVault) revert SourcePortal__NotMultiAssetVault(msg.sender, i_multiAssetVault);
        _;
    }

    constructor(
        address _lzEndpoint,
        address _globalOwnable,
        address _multiAssetVault
    )
        OFT("Portal", "PORTAL", _lzEndpoint, address(1))
        Ownable(address(1))
        GlobalOwnerChecker(_globalOwnable)
    {
        if (_lzEndpoint == address(0) || _globalOwnable == address(0) || _multiAssetVault == address(0)) {
            revert SourcePortal__AddressZero();
        }

        i_multiAssetVault = _multiAssetVault;
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
