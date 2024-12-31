// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { PythUtils } from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

import { IPythOracle } from "./interfaces/IPythOracle.sol";

import { GlobalOwnerChecker } from "./utils/GlobalOwnerChecker.sol";
import { Math } from "./utils/Math.sol";

contract PythOracle is GlobalOwnerChecker, IPythOracle {
    uint8 private constant TARGET_DECIMALS = 18;
    uint16 private constant MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS = 1000;

    IPyth private immutable i_pyth;
    mapping(address asset => OracleConfig oracleConfig) private s_assetToOracleConfig;

    constructor(address _globalOwnable, address _pyth) GlobalOwnerChecker(_globalOwnable) {
        if (_pyth == address(0)) revert PythOracle__AddressZero();

        i_pyth = IPyth(_pyth);
    }

    function setOracleConfig(address _asset, OracleConfig memory _oracleConfig) external onlyGlobalOwner {
        if (_asset == address(0)) revert PythOracle__AddressZero();
        if (_oracleConfig.priceFeedId == 0 || _oracleConfig.stalenessThreshold == 0) {
            revert PythOracle__InvalidOracleConfig(_asset, _oracleConfig);
        }

        s_assetToOracleConfig[_asset] = _oracleConfig;

        emit OracleConfigSet(_asset, _oracleConfig);
    }

    function getPriceInUsd(address _asset) external view returns (uint256) {
        OracleConfig memory oracleConfig = s_assetToOracleConfig[_asset];
        if (oracleConfig.priceFeedId == 0) revert PythOracle__OracleNotSet(_asset);

        PythStructs.Price memory priceStruct =
            i_pyth.getPriceNoOlderThan(oracleConfig.priceFeedId, oracleConfig.stalenessThreshold);
        uint256 priceInTargetDecimals = PythUtils.convertToUint(priceStruct.price, priceStruct.expo, TARGET_DECIMALS);
        uint256 confidenceInTargetDecimals =
            PythUtils.convertToUint(int64(priceStruct.conf), priceStruct.expo, TARGET_DECIMALS);

        if (
            confidenceInTargetDecimals
                > Math.applyPercentage(priceInTargetDecimals, MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS)
        ) revert PythOracle__ConfidenceThresholdBreached(confidenceInTargetDecimals, priceInTargetDecimals);

        return priceInTargetDecimals;
    }

    function getTargetDecimals() external pure returns (uint8) {
        return TARGET_DECIMALS;
    }

    function getMaxAllowedConfidenceAsAPercentageOfPriceInBPs() external pure returns (uint16) {
        return MAX_ALLOWED_CONFIDENCE_AS_AS_PERCENTAGE_OF_PRICE_IN_BPS;
    }

    function getPyth() external view returns (address) {
        return address(i_pyth);
    }

    function getOracleConfig(address _asset) external view returns (OracleConfig memory) {
        return s_assetToOracleConfig[_asset];
    }
}
