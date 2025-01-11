// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IDestinationPortal } from "./interfaces/IDestinationPortal.sol";

/// @title DestinationPortal.
/// @author mgnfy-view.
/// @notice This contract will be deployed on destination chains, and hooked up
/// with the source portal. This allows seamless, native bridging of the stablecoin
/// accross multiple evm-compatible networks supported by LayerZero.
contract DestinationPortal is OFT, IDestinationPortal {
    uint8 private constant DECIMALS = 6;

    /// @notice Sets the ERC20 metadata, layer zero endpoint, and owner contract.
    /// @param _lzEndpoint The layer zero endpoint address that enables cross-chain OApp communications.
    /// @param _owner The owner address.
    constructor(address _lzEndpoint, address _owner) OFT("Portal", "PORTAL", _lzEndpoint, _owner) Ownable(_owner) {
        if (_lzEndpoint == address(0) || _owner == address(0)) revert DestinationPortal__AddressZero();
    }

    /// @notice Gets the ERC20's decimals (6).
    /// @return The token decimals.
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
