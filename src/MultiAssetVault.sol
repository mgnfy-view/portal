// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { IMultiAssetVault } from "./interfaces/IMultiAssetVault.sol";

import { IPythOracle } from "./interfaces/IPythOracle.sol";
import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

contract MultiAssetVault is IMultiAssetVault {
    using SafeERC20 for IERC20;

    IAssetRegistry private immutable i_assetRegistry;
    IPythOracle private immutable i_pythOracle;
    ISourcePortal private immutable i_sourcePortal;
    mapping(address user => mapping(address asset => Position position)) private s_positions;

    constructor(address _assetRegistry, address _pythOracle, address _sourcePortal) {
        if (_assetRegistry == address(0) || _pythOracle == address(0)) revert MultiAssetVault__AddressZero();

        i_assetRegistry = IAssetRegistry(_assetRegistry);
        i_pythOracle = IPythOracle(_pythOracle);
        i_sourcePortal = ISourcePortal(_sourcePortal);
    }

    function depositCollateral(address _asset, uint256 _amount, address _for) external {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();
        if (_for == address(0)) revert MultiAssetVault__AddressZero();

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        Position memory position = s_positions[_for][_asset];
        position.amountDeposited += _amount;
        s_positions[_for][_asset] = position;

        emit AmountDeposited(msg.sender, _asset, _amount, _for);
    }

    function withdrawCollateral(address _asset, uint256 _amount, address _to) external {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();
        if (_to == address(0)) revert MultiAssetVault__AddressZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountDeposited -= _amount;
        s_positions[msg.sender][_asset] = position;

        if (!_isPositionHealthy(_asset, position)) revert MultiAssetVault__MinimumCollateralisationRatioBreached();
        IERC20(_asset).safeTransfer(_to, _amount);

        emit AmountWithdrawn(msg.sender, _asset, _amount, _to);
    }

    function mint(address _asset, uint256 _amount, address _to) external {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();
        if (_to == address(0)) revert MultiAssetVault__AddressZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountMinted += _amount;
        s_positions[msg.sender][_asset] = position;

        if (!_isPositionHealthy(_asset, position)) revert MultiAssetVault__MinimumCollateralisationRatioBreached();
        i_sourcePortal.mint(_to, _amount);

        emit PortalMinted(msg.sender, _asset, _amount, _to);
    }

    function burn(address _asset, uint256 _amount) external {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountMinted -= _amount;
        s_positions[msg.sender][_asset] = position;

        i_sourcePortal.burn(msg.sender, _amount);

        emit PortalBurned(msg.sender, _asset, _amount);
    }

    function _revertIfAssetNotWhitelisted(address _asset) internal view {
        if (!i_assetRegistry.isAssetWhitelisted(_asset)) revert MultiAssetVault__AssetNotWhitelisted(_asset);
    }

    function _isPositionHealthy(address _asset, Position memory _position) internal view returns (bool) {
        IAssetRegistry.AssetConfig memory assetConfig = i_assetRegistry.getAssetConfig(_asset);

        if (_getCollateralisationRatio(_asset, _position) < assetConfig.minimumCollateralisationRatio) {
            return false;
        }
        return true;
    }

    function _getCollateralisationRatio(address _asset, Position memory _position) internal view returns (uint256) {
        if (_position.amountMinted == 0) return type(uint256).max;
        return _getDepositedAmountValueInUsd(_asset, _position.amountDeposited)
            * 10 ** IERC20Metadata(address(i_sourcePortal)).decimals() / _position.amountMinted;
    }

    function _getDepositedAmountValueInUsd(address _asset, uint256 _depositedAmount) internal view returns (uint256) {
        uint256 price = i_pythOracle.getPriceInUsd(_asset);
        return (_depositedAmount * price) / 10 ** IERC20Metadata(_asset).decimals();
    }
}
