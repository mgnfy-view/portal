// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";

/// @title SourcePortal.
/// @author mgnfy-view.
/// @notice An ERC20 contract to be deployed on the source chain. Minting and burning
/// will be managed by the `MultiAssetVault`. Portal ERC20 can be bridged to destination
/// chains set as peers by the global owner.
contract SourcePortal is OFT, GlobalOwnerChecker, ISourcePortal {
    uint8 private constant DECIMALS = 6;
    address private constant DEAD_ADDRESS = address(1);

    /// @dev The `MultiAssetVault` address.
    address private s_multiAssetVault;

    modifier onlyMultiAssetVault() {
        if (msg.sender != s_multiAssetVault) revert SourcePortal__NotMultiAssetVault(msg.sender, s_multiAssetVault);
        _;
    }

    /// @notice Sets the ERC20 metadata, layer zero endpoint, and `GlobalOwnable` contract.
    /// @param _lzEndpoint The layer zero endpoint address that enables cross-chain OApp communications.
    /// @param _globalOwnable The `GlobalOwnable` contract address.
    constructor(
        address _lzEndpoint,
        address _globalOwnable
    )
        OFT("Portal", "PORTAL", _lzEndpoint, DEAD_ADDRESS)
        Ownable(DEAD_ADDRESS)
        GlobalOwnerChecker(_globalOwnable)
    { }

    /// @notice Initializes the `MultiAssetVault` address since the source portal is deployed before
    /// the `MultiAssetVault`.
    /// @param _multiAssetVault The `MultiAssetVault` address.
    function initializeMultiAssetVaultAddress(address _multiAssetVault) external onlyOwner {
        if (s_multiAssetVault != address(0)) revert SourcePortal__MultiAssetVaultAlreadySet(s_multiAssetVault);

        s_multiAssetVault = _multiAssetVault;

        emit MultiAssetVaultSet(_multiAssetVault);
    }

    /// @notice Allows the `MultiAssetVault` to mint source portal to an arbitrary address.
    /// @param _to The recipient of source portal.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external onlyMultiAssetVault {
        _mint(_to, _amount);
    }

    /// @notice Allows the `MultiAssetVault` to burn source portal from an arbitrary address.
    /// @param _to The address whose source portal is being burned.
    /// @param _amount The amount of tokens to burn.
    function burn(address _to, uint256 _amount) external onlyMultiAssetVault {
        _burn(_to, _amount);
    }

    /// @notice Gets the current global owner.
    /// @return The current global owner.
    function owner() public view override returns (address) {
        return i_globalOwnable.owner();
    }

    /// @notice Gets the ERC20's decimals (6).
    /// @return The token decimals.
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
