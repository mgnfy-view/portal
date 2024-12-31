// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPythOracle {
    struct OracleConfig {
        bytes32 priceFeedId;
        uint256 stalenessThreshold;
    }

    event OracleConfigSet(address indexed asset, OracleConfig indexed assetOracleConfig);

    error PythOracle__NotAssetRegistry(address caller, address assetRegistry);
    error PythOracle__AddressZero();
    error PythOracle__InvalidOracleConfig(address asset, OracleConfig oracleConfig);
    error PythOracle__OracleNotSet(address asset);
    error PythOracle__ConfidenceThresholdBreached(uint256 confidenceInTargetDecimals, uint256 priceInTargetDecimals);

    function setOracleConfig(address _asset, OracleConfig memory _oracleConfig) external;

    function getPriceInUsd(address _asset) external view returns (uint256);

    function getTargetDecimals() external pure returns (uint8);

    function getMaxAllowedConfidenceAsAPercentageOfPriceInBPs() external pure returns (uint16);

    function getPyth() external view returns (address);

    function getOracleConfig(address _asset) external view returns (OracleConfig memory);
}
