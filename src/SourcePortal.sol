// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

contract SourcePortal is OFT, ISourcePortal {
    uint8 private constant DECIMALS = 6;

    address private immutable i_multiAssetVault;

    modifier onlyMultiAssetVault() {
        if (msg.sender != i_multiAssetVault) revert SourcePortal__NotMultiAssetVault(msg.sender, i_multiAssetVault);
        _;
    }

    constructor(
        address _lzEndpoint,
        address _globalOwner,
        address _multiAssetVault
    )
        OFT("Portal", "PORTAL", _lzEndpoint, _globalOwner)
        Ownable(_globalOwner)
    {
        i_multiAssetVault = _multiAssetVault;
    }

    function mint(address _to, uint256 _amount) external onlyMultiAssetVault {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external onlyMultiAssetVault {
        _burn(_to, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
