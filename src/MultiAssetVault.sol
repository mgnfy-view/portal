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

/// @title MultiAssetVault.
/// @author mgnfy-view.
/// @notice This contract serves as the entrypoint for users to deposit/withdraw collateral,
/// mint/burn the portal stablecoin, and liquidate unhealthy positions.
contract MultiAssetVault is IMultiAssetVault {
    using SafeERC20 for IERC20;

    /// @dev The percentage of liquidation reward the protocol is entitled to.
    uint16 private constant LIQUIDATION_REWARD_PROTOCOL_CUT_IN_BPS = 5_000;
    /// @dev The minimum portal stablecoin amount that each position should hold.
    uint256 private constant MINIMUM_PORTAL_AMOUNT_IN_POSITION = 50e6;

    /// @dev Address of the `AssetRegistry` that whitelists assets as collateral.
    IAssetRegistry private immutable i_assetRegistry;
    /// @dev Pyth oracle to fetch collateral prices from (in USD).
    IPythOracle private immutable i_pythOracle;
    /// @dev Address of the Portal stablecoin.
    ISourcePortal private immutable i_sourcePortal;
    /// @dev Maps each user to their position (deposited collateral against stablecoin amount minted).
    mapping(address user => mapping(address asset => Position position)) private s_positions;
    /// @dev The setter of the liquidation reward recipient.
    address private s_liquidationPenaltyRecipientSetter;
    /// @dev The recipient of the liquidation reward cut.
    address private s_liquidationPenaltyRecipient;
    /// @dev Tracks the collected liquidation penalties in different collateral assets.
    mapping(address asset => uint256 collectedLiquidationPenalty) private s_collectedLiquidationPenalties;

    modifier onlyLiquidationPenaltyRecipientSetter() {
        if (msg.sender != s_liquidationPenaltyRecipientSetter) {
            revert MultiAssetVault_NotLiquidationPenaltyRecipientSetter(msg.sender, s_liquidationPenaltyRecipientSetter);
        }
        _;
    }

    /// @notice Initializes the asset registry, pyth oracle, portal, liquidation reward recipient
    /// setter, and liquidation reward recipient.
    /// @param _assetRegistry Address of the `AssetRegistry`.
    /// @param _pythOracle Address of the `PythOracle`.
    /// @param _sourcePortal Address of the Portal ERC20.
    /// @param _liquidationPenaltyRecipientSetter Address of the liquidation reward recipient setter.
    /// @param _liquidationPenaltyRecipient Address of the liquidation reward recipient.
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

    /// @notice Allows the liquidation reward recipient setter to set the new liquidation reward recipient setter.
    /// @param _newLiquidationPenaltyRecipientSetter The new liquidation reward recipient setter.
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

    /// @notice Allows the liquidation reward recipient setter to set the new liquidation reward recipient.
    /// @param _newLiquidationPenaltyRecipient The new liquidation reward recipient.
    function setLiquidationPenaltyRecipient(
        address _newLiquidationPenaltyRecipient
    )
        external
        onlyLiquidationPenaltyRecipientSetter
    {
        s_liquidationPenaltyRecipient = _newLiquidationPenaltyRecipient;

        emit NewLiquidationPenaltyRecipientSet(_newLiquidationPenaltyRecipient);
    }

    /// Allows anyone to batch claim the collected liquidation rewards on behalf of the liquidation reward recipient.
    /// @param _assets The asset address.
    function batchCollectLiquidationPenalties(address[] memory _assets) external {
        uint256 length = _assets.length;

        for (uint256 i; i < length; ++i) {
            collectLiquidationPenalty(_assets[i]);
        }
    }

    /// @notice Enables a user to batch deposit whitelisted assets as collateral.
    /// @param _assets The assets to deposit.
    /// @param _amounts The amounts to deposit.
    /// @param _for The address to deposit on behalf of.
    function batchDepositCollateral(address[] memory _assets, uint256[] memory _amounts, address _for) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            depositCollateral(_assets[i], _amounts[i], _for);
        }
    }

    /// @notice Enables a user to batch withdraw assets deposited as collateral.
    /// @param _assets The assets to wihdraw.
    /// @param _amounts The amounts to withdraw.
    /// @param _to The address to direct the withdrawn amounts to.
    function batchWithdrawCollateral(address[] memory _assets, uint256[] memory _amounts, address _to) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            withdrawCollateral(_assets[i], _amounts[i], _to);
        }
    }

    /// @notice Allows a user to batch mint Portal stablecoin accross against multiple assets put up as
    /// collateral.
    /// @param _assets The assets to wihdraw.
    /// @param _amounts The amounts to mint.
    /// @param _to The address to direct the minted portal amounts to.
    function batchMintPortal(address[] memory _assets, uint256[] memory _amounts, address _to) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            mintPortal(_assets[i], _amounts[i], _to);
        }
    }

    /// @notice Allows a user to batch burn Portal stablecoin accross against multiple assets put up as
    /// collateral.
    /// @param _assets The assets address.
    /// @param _amounts The amounts to burn.
    function batchBurnPortal(address[] memory _assets, uint256[] memory _amounts) external {
        uint256 length = _assets.length;
        if (length != _amounts.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            burnPortal(_assets[i], _amounts[i]);
        }
    }

    /// @notice Enables a user to batch deposit whitelisted assets as collateral and mint portal against them.
    /// @param _assets The assets to deposit.
    /// @param _amountsToDeposit The amounts to deposit.
    /// @param _amountsToMint The amounts of portal to mint against each asset amount deposit.
    /// @param _to The address to direct the minted portal ERC20 to.
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

    /// @notice Enables a user to batch withdraw collateral and burn portal.
    /// @param _assets The assets to burn.
    /// @param _amountsToBurn The amounts of portal to burn.
    /// @param _amountsToWithdraw The amounts of assets to withdraw.
    /// @param _to The address to direct the withdrawn assets to.
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

    /// @notice Allows anyone to batch liquidate multiple unhealthy positions and claim the liquidation reward.
    /// @param _users The users to liquidate.
    /// @param _assets The asset addresses.
    /// @param _to The address to direct the liquidation rewards to.
    function batchLiquidate(address[] memory _users, address[] memory _assets, address _to) external {
        uint256 length = _users.length;
        if (length != _assets.length) revert MultiAssetVault__ArrayLengthMismatch();

        for (uint256 i; i < length; ++i) {
            liquidate(_users[i], _assets[i], _to);
        }
    }

    /// @notice Allows anyone to claim the collected liquidation rewards on behalf of the liquidation
    /// reward recipient.
    /// @param _asset The asset address.
    function collectLiquidationPenalty(address _asset) public {
        address recipient = s_liquidationPenaltyRecipient;
        uint256 amount = s_collectedLiquidationPenalties[_asset];
        if (amount == 0) revert MultiAssetVault__AmountZero();

        s_collectedLiquidationPenalties[_asset] = 0;
        IERC20(_asset).safeTransfer(recipient, amount);

        emit LiquidationPenaltyCollected(_asset, amount, recipient);
    }

    /// @notice Allows a user to deposit a whitelisted asset as collateral.
    /// @param _asset The asset to deposit.
    /// @param _amount The amount to deposit.
    /// @param _for The address to deposit on behalf of.
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

    /// @notice Enables a user to withdraw an asset deposited as collateral.
    /// @param _asset The asset to wihdraw.
    /// @param _amount The amount to withdraw.
    /// @param _to The address to direct the withdrawn amount to.
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

    /// @notice Allows a user to mint Portal stablecoin against an asset put up as collateral.
    /// @param _asset The asset to wihdraw.
    /// @param _amount The amount to mint.
    /// @param _to The address to direct the minted portal amount to.
    function mintPortal(address _asset, uint256 _amount, address _to) public {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();
        if (_to == address(0)) revert MultiAssetVault__AddressZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountMinted += _amount;
        s_positions[msg.sender][_asset] = position;

        if (!_isPositionHealthy(_asset, position)) revert MultiAssetVault__MinimumCollateralisationRatioBreached();
        _revertIfPositionDoesNotHaveMinimumPortalAmountMinted(position);
        i_sourcePortal.mint(_to, _amount);

        emit PortalMinted(msg.sender, _asset, _amount, _to);
    }

    /// @notice Allows a user to burn their Portal amount.
    /// @param _asset The asset address.
    /// @param _amount The amount to burn.
    function burnPortal(address _asset, uint256 _amount) public {
        _revertIfAssetNotWhitelisted(_asset);
        if (_amount == 0) revert MultiAssetVault__AmountZero();

        Position memory position = s_positions[msg.sender][_asset];
        position.amountMinted -= _amount;
        _revertIfPositionDoesNotHaveMinimumPortalAmountMinted(position);

        s_positions[msg.sender][_asset] = position;
        i_sourcePortal.burn(msg.sender, _amount);

        emit PortalBurned(msg.sender, _asset, _amount);
    }

    /// @notice Enables a user to deposit a whitelisted asset as collateral and mint portal ERC20.
    /// @param _asset The asset to deposit.
    /// @param _amountToDeposit The amount to deposit.
    /// @param _amountToMint The amount of portal to mint.
    /// @param _to The address to direct the minted portal ERC20 to.
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

    /// @notice Enables a user to withdraw collateral and burn portal.
    /// @param _asset The asset to burn.
    /// @param _amountToBurn The amount of portal to burn.
    /// @param _amountToWithdraw The amount of an asset to withdraw.
    /// @param _to The address to direct the withdrawn asset to.
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

    /// @notice Allows anyone to liquidate an unhealthy position and claim the liquidation reward.
    /// @param _user The user to liquidate.
    /// @param _asset The asset address.
    /// @param _to The address to direct the liquidation reward to.
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

    /// @notice Reverts if the asset is not whitelisted in the `AssetRegistry`.
    /// @param _asset The asset address.
    function _revertIfAssetNotWhitelisted(address _asset) internal view {
        if (!i_assetRegistry.isAssetWhitelisted(_asset)) revert MultiAssetVault__AssetNotWhitelisted(_asset);
    }

    /// @notice Checks if a position is healthy.
    /// @param _asset The asset address.
    /// @param _position The position details.
    /// @return A boolean indicating whether the position is healthy or not.
    function _isPositionHealthy(address _asset, Position memory _position) internal view returns (bool) {
        IAssetRegistry.AssetConfig memory assetConfig = i_assetRegistry.getAssetConfig(_asset);

        if (_getCollateralisationRatio(_asset, _position) < assetConfig.minimumCollateralisationRatio) {
            return false;
        }
        return true;
    }

    /// @notice Reverts if the position does not hold the minimum portal amount, if the amount is greater than 0.
    /// @param _position The position details.
    function _revertIfPositionDoesNotHaveMinimumPortalAmountMinted(Position memory _position) internal pure {
        if (_position.amountMinted > 0 && _position.amountMinted < MINIMUM_PORTAL_AMOUNT_IN_POSITION) {
            revert MultiAssetVault__NotEnoughPortalMinted(_position.amountMinted, MINIMUM_PORTAL_AMOUNT_IN_POSITION);
        }
    }

    /// @notice Gets a position's collateralisation ratio.
    /// @param _asset The asset address.
    /// @param _position The position details.
    /// @return The collateralisation ratio.
    function _getCollateralisationRatio(address _asset, Position memory _position) internal view returns (uint256) {
        if (_position.amountMinted == 0) return type(uint256).max;
        return _getDepositedAmountValueInUsd(_asset, _position.amountDeposited)
            * 10 ** IERC20Metadata(address(i_sourcePortal)).decimals() / _position.amountMinted;
    }

    /// @notice Gets the value of the deposited asset in USD (with 18 deccimals representation).
    /// @param _asset The asset address.
    /// @param _depositedAmount The amount of asset deposited.
    /// @return The value of the deposited asset in USD (with 18 deccimals representation).
    function _getDepositedAmountValueInUsd(address _asset, uint256 _depositedAmount) internal view returns (uint256) {
        uint256 price = i_pythOracle.getPriceInUsd(_asset);
        return (_depositedAmount * price) / 10 ** IERC20Metadata(_asset).decimals();
    }

    /// @notice Checks if the asset is whitelisted or not.
    /// @param _asset The asset address.
    /// @return A boolean indicating whether the asset is whitelisted or not.
    function isAssetWhitelisted(address _asset) external view returns (bool) {
        return i_assetRegistry.isAssetWhitelisted(_asset);
    }

    /// @notice Gets the value of the deposited asset in USD (with 18 deccimals representation).
    /// @param _user The user address.
    /// @param _asset The asset address.
    /// @return The value of the deposited asset in USD (with 18 deccimals representation).
    function getPositionValueInUsd(address _user, address _asset) external view returns (uint256) {
        Position memory position = s_positions[_user][_asset];

        return _getDepositedAmountValueInUsd(_asset, position.amountDeposited);
    }

    /// @notice Gets a position's collateralisation ratio.
    /// @param _user The user address.
    /// @param _asset The asset address.
    /// @return The collateralisation ratio.
    function getCollateralisationRatio(address _user, address _asset) external view returns (uint256) {
        Position memory position = s_positions[_user][_asset];

        return _getCollateralisationRatio(_asset, position);
    }

    /// @notice Checks if a position is healthy.
    /// @param _user The user address.
    /// @param _asset The asset address.
    /// @return A boolean indicating whether the position is healthy or not.
    function isPositionIsHealthy(address _user, address _asset) external view returns (bool) {
        Position memory position = s_positions[_user][_asset];

        return _isPositionHealthy(_asset, position);
    }

    /// @notice Gets the protocol's cut of the liquidation reward.
    /// @return The protocol's cut of the liquidation reward.
    function getLiquidationRewardProtocolCutInBPs() external pure returns (uint16) {
        return LIQUIDATION_REWARD_PROTOCOL_CUT_IN_BPS;
    }

    /// @notice Gets the address of the asset registry.
    /// @return The address of the asset registry.
    function getAssetRegistry() external view returns (address) {
        return address(i_assetRegistry);
    }

    /// @notice Gets the Pyth oracle address.
    /// @return The Pyth oracle address.
    function getPythOracle() external view returns (address) {
        return address(i_pythOracle);
    }

    /// @notice Gets the Source Portal address.
    /// @return The Source Portal address.
    function getSourcePortal() external view returns (address) {
        return address(i_sourcePortal);
    }

    /// @notice Gets the details of a user's position.
    /// @param _user The user address.
    /// @param _asset The asset address.
    /// @return The user's position's details.
    function getPosition(address _user, address _asset) external view returns (Position memory) {
        return s_positions[_user][_asset];
    }

    /// @notice Gets the liquidation reward recipient setter.
    /// @return The liquidation reward recipient setter.
    function getLiquidationPenaltyRecipientSetter() external view returns (address) {
        return s_liquidationPenaltyRecipientSetter;
    }

    /// @notice Gets the liquidation reward recipient.
    /// @return The liquidation reward recipient.
    function getLiquidationPenaltyRecipient() external view returns (address) {
        return s_liquidationPenaltyRecipient;
    }

    /// @notice Gets the collected liquidation penalties.
    /// @param _asset The asset address.
    /// @return The collected liquidation penalties.
    function getCollectedLiquidationPenalty(address _asset) external view returns (uint256) {
        return s_collectedLiquidationPenalties[_asset];
    }
}
