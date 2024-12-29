// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract DestinationPortal is OFT {
    uint8 private constant DECIMALS = 6;

    constructor(
        address _lzEndpoint,
        address _globalOwner
    )
        OFT("Portal", "PORTAL", _lzEndpoint, _globalOwner)
        Ownable(_globalOwner)
    { }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
