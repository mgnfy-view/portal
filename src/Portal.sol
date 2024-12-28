// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MyOFT is OFT {
    uint8 private constant DECIMALS = 6;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    )
        OFT(_name, _symbol, _lzEndpoint, _delegate)
        Ownable(msg.sender)
    { }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
