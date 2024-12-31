// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IDestinationPortal } from "./interfaces/IDestinationPortal.sol";

contract DestinationPortal is OFT, IDestinationPortal {
    uint8 private constant DECIMALS = 6;

    constructor(address _lzEndpoint, address _owner) OFT("Portal", "PORTAL", _lzEndpoint, _owner) Ownable(_owner) {
        if (_lzEndpoint == address(0) || _owner == address(0)) revert DestinationPortal__AddressZero();
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
