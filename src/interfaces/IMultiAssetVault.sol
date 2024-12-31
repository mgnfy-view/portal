// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IMultiAssetVault {
    struct Position {
        uint256 amountDeposited;
        uint256 amountMinted;
    }

    event NewLiquidationPenaltyRecipientSet(address indexed newLiquidationPenaltyRecipient);
    event LiquidationPenaltyCollected(address indexed asset, uint256 indexed amount, address indexed recipient);
    event AmountDeposited(address by, address indexed asset, uint256 indexed amount, address indexed onBehalfOf);
    event AmountWithdrawn(address indexed by, address indexed asset, uint256 indexed amount, address to);
    event PortalMinted(address indexed by, address indexed asset, uint256 indexed amount, address to);
    event PortalBurned(address indexed by, address indexed asset, uint256 indexed amount);
    event Liquidated(address indexed by, address indexed asset, address indexed user, address to);

    error MultiAssetVault_NotLiquidationPenaltyRecipientSetter(
        address caller, address liquidationPenaltyRecipientSetter
    );
    error MultiAssetVault__AddressZero();
    error MultiAssetVault__ArrayLengthMismatch();
    error MultiAssetVault__AssetNotWhitelisted(address asset);
    error MultiAssetVault__AmountZero();
    error MultiAssetVault__MinimumCollateralisationRatioBreached();
    error MultiAssetVault__CannotLiquidateHealthyPosition(address user, address asset, Position position);

    function setLiquidationPenaltyRecipient(address _newLiquidationPenaltyRecipient) external;

    function batchCollectLiquidationPenalties(address[] memory _assets) external;

    function batchDepositCollateral(address[] memory _assets, uint256[] memory _amounts, address _for) external;

    function batchWithdrawCollateral(address[] memory _assets, uint256[] memory _amounts, address _to) external;

    function batchMintPortal(address[] memory _assets, uint256[] memory _amounts, address _to) external;

    function batchBurnPortal(address[] memory _assets, uint256[] memory _amounts) external;

    function batchDepositCollateralAndMintPortal(
        address[] memory _assets,
        uint256[] memory _amountsToDeposit,
        uint256[] memory _amountsToMint,
        address _to
    )
        external;

    function batchBurnPortalAndWithdrawCollateral(
        address[] memory _assets,
        uint256[] memory _amountsToBurn,
        uint256[] memory _amountsToWithdraw,
        address _to
    )
        external;

    function batchLiquidate(address[] memory _users, address[] memory _assets, address _to) external;

    function collectLiquidationPenalty(address _asset) external;

    function depositCollateral(address _asset, uint256 _amount, address _for) external;

    function withdrawCollateral(address _asset, uint256 _amount, address _to) external;

    function mintPortal(address _asset, uint256 _amount, address _to) external;

    function burnPortal(address _asset, uint256 _amount) external;

    function depositCollateralAndMintPortal(
        address _asset,
        uint256 _amountToDeposit,
        uint256 _amountToMint,
        address _to
    )
        external;

    function burnPortalAndWithdrawCollateral(
        address _asset,
        uint256 _amountToBurn,
        uint256 _amountToWithdraw,
        address _to
    )
        external;

    function liquidate(address _user, address _asset, address _to) external;

    function isAssetWhitelisted(address _asset) external view returns (bool);

    function getPositionValueInUsd(address _user, address _asset) external view returns (uint256);

    function getCollateralisationRatio(address _user, address _asset) external view returns (uint256);

    function isPositionIsHealthy(address _user, address _asset) external view returns (bool);

    function getLiquidationRewardProtocolCutInBPs() external pure returns (uint16);

    function getAssetRegistry() external view returns (address);

    function getPythOracle() external view returns (address);

    function getSourcePortal() external view returns (address);

    function getPosition(address _user, address _asset) external view returns (Position memory);

    function getLiquidationPenaltyRecipientSetter() external view returns (address);

    function getLiquidationPenaltyRecipient() external view returns (address);

    function getCollectedLiquidationPenalty(address _asset) external view returns (uint256);
}
