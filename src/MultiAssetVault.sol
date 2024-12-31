// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { IMultiAssetVault } from "./interfaces/IMultiAssetVault.sol";
import { IPythOracle } from "./interfaces/IPythOracle.sol";
import { ISourcePortal } from "./interfaces/ISourcePortal.sol";

import { Math } from "./utils/Math.sol";

contract MultiAssetVault is IMultiAssetVault {
    using SafeERC20 for IERC20;

    uint16 private constant LIQUIDATION_REWARD_PROTOCOL_CUT_IN_BPS = 5_000;

    IAssetRegistry private immutable i_assetRegistry;
    IPythOracle private immutable i_pythOracle;
    ISourcePortal private immutable i_sourcePortal;
    mapping(address user => mapping(address asset => Position position)) private s_positions;
    address private s_liquidationPenaltyRecipientSetter;
    address private s_liquidationPenaltyRecipient;
    mapping(address asset => uint256 collectedLiquidationPenalty) private s_collectedLiquidationPenalties;

    modifier onlyLiquidationPenaltyRecipientSetter() {
        if (msg.sender != s_liquidationPenaltyRecipientSetter) {
            revert MultiAssetVault_NotLiquidationPenaltyRecipientSetter(msg.sender, s_liquidationPenaltyRecipientSetter);
        }
        _;
    }

    constructor(
        address _assetRegistry,
        address _pythOracle,
        address _sourcePortal,
        address _liquidationPenaltyRecipientSetter,
        address _liquidationPenaltyRecipient
    ) {
        if (
            _assetRegistry == address(0) || _pythOracle == address(0) || _sourcePortal == address(0)
                || _liquidationPenaltyRecipientSetter == address(0)
        ) revert MultiAssetVault__AddressZero();

        i_assetRegistry = IAssetRegistry(_assetRegistry);
        i_pythOracle = IPythOracle(_pythOracle);
        i_sourcePortal = ISourcePortal(_sourcePortal);
        s_liquidationPenaltyRecipientSetter = _liquidationPenaltyRecipientSetter;
        s_liquidationPenaltyRecipient = _liquidationPenaltyRecipient;
    }

    function setLiquidationPenaltyRecipientSetter(
        address _newLiquidationPenaltyRecipientSetter
    )
        external
        onlyLiquidationPenaltyRecipientSetter
    {
        if (_newLiquidationPenaltyRecipientSetter == address(0)) revert MultiAssetVault__AddressZero();

        s_liquidationPenaltyRecipientSetter = _newLiquidationPenaltyRecipientSetter;

        emit NewLiquidationPenaltyRecipientSetterSet(_newLiquidationPenaltyRecipientSetter);
    }

    function setLiquidationPenaltyRecipient(
        address _newLiquidationPenaltyRecipient
    )
        external
        onlyLiquidationPenaltyRecipientSetter
    {
        s_liquidationPenaltyRecipient = _newLiquidationPenaltyRecipient;

        emit NewLiquidationPenaltyRecipientSet(_newLiquidationPenaltyRecipient);
    }

    function batchCollectLiquidationPenalties(address[] memory _assets) external {
        uint256 length = _assets.length;

        for (uint256 i; i < length; ++i) {
            collectLiquidationPenalty(_assets[i]);
        }
    }

    function batchDepositCollateral(address[] memory _assets, uint256[] memory _amounts, address _for) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            depositCollateral(_assets[i], _amounts[i], _for);
        }
    }

    function batchWithdrawCollateral(address[] memory _assets, uint256[] memory _amounts, address _to) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            withdrawCollateral(_assets[i], _amounts[i], _to);
        }
    }

    function batchMintPortal(address[] memory _assets, uint256[] memory _amounts, address _to) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            mintPortal(_assets[i], _amounts[i], _to);
        }
    }

    function batchBurnPortal(address[] memory _assets, uint256[] memory _amounts) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            burnPortal(_assets[i], _amounts[i]);
        }
    }

    function batchDepositCollateralAndMintPortal(
        address[] memory _assets,
        uint256[] memory _amountsToDeposit,
        uint256[] memory _amountsToMint,
        address _to
    )
        external
    {
        uint256 length = _assets.length;
        if (length != _amountsToDeposit.length || length != _amountsToMint.length) {
            revert MultiAssetVault__ArrayLengthMismatch();
        }

        for (uint256 i; i < length; ++i) {
            depositCollateralAndMintPortal(_assets[i], _amountsToDeposit[i], _amountsToMint[i], _to);
        }
    }

    function batchBurnPortalAndWithdrawCollateral(
        address[] memory _assets,
        uint256[] memory _amountsToBurn,
        uint256[] memory _amountsToWithdraw,
        address _to
    )
        external
    {
        uint256 length = _assets.length;
        if (length != _amountsToBurn.length || length != _amountsToWithdraw.length) {
            revert MultiAssetVault__ArrayLengthMismatch();
        }

        for (uint256 i; i < length; ++i) {
            burnPortalAndWithdrawCollateral(_assets[i], _amountsToBurn[i], _amountsToWithdraw[i], _to);
        }
    }

    function batchLiquidate(address[] memory _users, address[] memory _assets, address _to) external {
        uint256 length = _users.length;
        if (length != _assets.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            liquidate(_users[i], _assets[i], _to);
        }
    }

    function collectLiquidationPenalty(address _asset) public {
        address recipient = s_liquidationPenaltyRecipient;
        uint256 amount = s_collectedLiquidationPenalties[_asset];
        if (amount == 0) revert MultiAssetVault__AmountZero();

        s_collectedLiquidationPenalties[_asset] = 0;
        IERC20(_asset).safeTransfer(recipient, amount);

        emit LiquidationPenaltyCollected(_asset, amount, recipient);
    }

    function depositCollateral(address _asset, uint256 _amount, address _for) public {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();
        if (_for == address(0)) revert MultiAssetVault__AddressZero();

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        Position memory position = s_positions[_for][_asset];
        position.amountDeposited += _amount;
        s_positions[_for][_asset] = position;

        emit AmountDeposited(msg.sender, _asset, _amount, _for);
    }

    function withdrawCollateral(address _asset, uint256 _amount, address _to) public {
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

    function mintPortal(address _asset, uint256 _amount, address _to) public {
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

    function burnPortal(address _asset, uint256 _amount) public {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountMinted -= _amount;
        s_positions[msg.sender][_asset] = position;

        i_sourcePortal.burn(msg.sender, _amount);

        emit PortalBurned(msg.sender, _asset, _amount);
    }

    function depositCollateralAndMintPortal(
        address _asset,
        uint256 _amountToDeposit,
        uint256 _amountToMint,
        address _to
    )
        public
    {
        depositCollateral(_asset, _amountToDeposit, msg.sender);
        mintPortal(_asset, _amountToMint, _to);
    }

    function burnPortalAndWithdrawCollateral(
        address _asset,
        uint256 _amountToBurn,
        uint256 _amountToWithdraw,
        address _to
    )
        public
    {
        burnPortal(_asset, _amountToBurn);
        withdrawCollateral(_asset, _amountToWithdraw, _to);
    }

    function liquidate(address _user, address _asset, address _to) public {
        _revertIfAssetNotWhitelisted(_asset);
        Position memory position = s_positions[_user][_asset];
        IAssetRegistry.AssetConfig memory assetConfig = i_assetRegistry.getAssetConfig(_asset);
        if (_isPositionHealthy(_asset, position)) {
            revert MultiAssetVault__CannotLiquidateHealthyPosition(_user, _asset, position);
        }

        i_sourcePortal.burn(msg.sender, position.amountMinted);

        uint256 equivalentAmountInAsset = (
            position.amountDeposited * position.amountMinted * 10 ** i_pythOracle.getTargetDecimals()
        ) / (_getDepositedAmountValueInUsd(_asset, position.amountDeposited) * 10 ** IERC20Metadata(_asset).decimals());
        uint256 liquidationReward = Math.applyPercentage(equivalentAmountInAsset, assetConfig.liquidationRewardInBPs);
        if (equivalentAmountInAsset >= position.amountDeposited) {
            equivalentAmountInAsset = position.amountDeposited;
            liquidationReward = 0;
        } else if (liquidationReward > position.amountDeposited - equivalentAmountInAsset) {
            liquidationReward = position.amountDeposited - equivalentAmountInAsset;
        }
        uint256 liquidationRewardProtocolCut =
            Math.applyPercentage(liquidationReward, LIQUIDATION_REWARD_PROTOCOL_CUT_IN_BPS);

        position.amountMinted = 0;
        position.amountDeposited -= equivalentAmountInAsset + liquidationReward;
        s_positions[_user][_asset] = position;
        if (s_liquidationPenaltyRecipient != address(0)) {
            s_collectedLiquidationPenalties[_asset] += liquidationRewardProtocolCut;
            IERC20(_asset).safeTransfer(_to, equivalentAmountInAsset + liquidationReward - liquidationRewardProtocolCut);
        } else {
            IERC20(_asset).safeTransfer(_to, equivalentAmountInAsset + liquidationReward);
        }

        emit Liquidated(msg.sender, _asset, _user, _to);
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

    function isAssetWhitelisted(address _asset) external view returns (bool) {
        return i_assetRegistry.isAssetWhitelisted(_asset);
    }

    function getPositionValueInUsd(address _user, address _asset) external view returns (uint256) {
        Position memory position = s_positions[_user][_asset];

        return _getDepositedAmountValueInUsd(_asset, position.amountDeposited);
    }

    function getCollateralisationRatio(address _user, address _asset) external view returns (uint256) {
        Position memory position = s_positions[_user][_asset];

        return _getCollateralisationRatio(_asset, position);
    }

    function isPositionIsHealthy(address _user, address _asset) external view returns (bool) {
        Position memory position = s_positions[_user][_asset];

        return _isPositionHealthy(_asset, position);
    }

    function getLiquidationRewardProtocolCutInBPs() external pure returns (uint16) {
        return LIQUIDATION_REWARD_PROTOCOL_CUT_IN_BPS;
    }

    function getAssetRegistry() external view returns (address) {
        return address(i_assetRegistry);
    }

    function getPythOracle() external view returns (address) {
        return address(i_pythOracle);
    }

    function getSourcePortal() external view returns (address) {
        return address(i_sourcePortal);
    }

    function getPosition(address _user, address _asset) external view returns (Position memory) {
        return s_positions[_user][_asset];
    }

    function getLiquidationPenaltyRecipientSetter() external view returns (address) {
        return s_liquidationPenaltyRecipientSetter;
    }

    function getLiquidationPenaltyRecipient() external view returns (address) {
        return s_liquidationPenaltyRecipient;
    }

    function getCollectedLiquidationPenalty(address _asset) external view returns (uint256) {
        return s_collectedLiquidationPenalties[_asset];
    }
}
