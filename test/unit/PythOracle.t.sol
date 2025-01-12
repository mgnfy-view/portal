// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { PythErrors } from "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";

import { IGlobalOwnerChecker } from "../../src/interfaces/IGlobalOwnerChecker.sol";
import { IPythOracle } from "../../src/interfaces/IPythOracle.sol";

import { Base } from "../utils/Base.sol";

contract PythOracleTest is Base {
    // Mainnet wBTC address
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    bytes32 public constant WBTC_PRICE_FEED_ID = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;

    function test_settingOracleConfigFailsIfCallerIsNotGlobalOwner() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(IGlobalOwnerChecker.GlobalOwnerChecker__NotOwner.selector, user1, owner));
        pythOracle.setOracleConfig(WBTC, IPythOracle.OracleConfig(WBTC_PRICE_FEED_ID, STALENESS_THRESHOLD));
        vm.stopPrank();
    }

    function test_settingOracleConfigFailsIfAssetIsAddressZero() external {
        vm.startPrank(owner);
        vm.expectRevert(IPythOracle.PythOracle__AddressZero.selector);
        pythOracle.setOracleConfig(address(0), IPythOracle.OracleConfig(WBTC_PRICE_FEED_ID, STALENESS_THRESHOLD));
        vm.stopPrank();
    }

    function test_settingOracleConfigFailsIfPriceFeedIdIsZero() external {
        IPythOracle.OracleConfig memory oracleConfig = IPythOracle.OracleConfig(0, STALENESS_THRESHOLD);

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IPythOracle.PythOracle__InvalidOracleConfig.selector, WBTC, oracleConfig)
        );
        pythOracle.setOracleConfig(WBTC, oracleConfig);
        vm.stopPrank();
    }

    function test_settingOracleConfigSucceeds() external {
        IPythOracle.OracleConfig memory oracleConfig = IPythOracle.OracleConfig(WBTC_PRICE_FEED_ID, STALENESS_THRESHOLD);

        vm.startPrank(owner);
        pythOracle.setOracleConfig(WBTC, oracleConfig);
        vm.stopPrank();

        IPythOracle.OracleConfig memory actualOracleConfig = pythOracle.getOracleConfig(WBTC);

        assertEq(actualOracleConfig.priceFeedId, WBTC_PRICE_FEED_ID);
        assertEq(actualOracleConfig.stalenessThreshold, STALENESS_THRESHOLD);
    }

    function test_settingOracleConfigEmitsEvent() external {
        IPythOracle.OracleConfig memory oracleConfig = IPythOracle.OracleConfig(WBTC_PRICE_FEED_ID, STALENESS_THRESHOLD);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IPythOracle.OracleConfigSet(WBTC, oracleConfig);
        pythOracle.setOracleConfig(WBTC, oracleConfig);
        vm.stopPrank();
    }

    function test_gettingPriceInUsdFailsForNonWhitelistedAssets() external {
        vm.expectRevert(abi.encodeWithSelector(IPythOracle.PythOracle__OracleNotSet.selector, WBTC));
        pythOracle.getPriceInUsd(WBTC);
    }

    function test_gettingPriceInUsdFailsIfPriceIsStale() external {
        uint256 skipBy = 1 days;
        skip(skipBy);

        vm.expectRevert(PythErrors.StalePrice.selector);
        pythOracle.getPriceInUsd(address(weth));
    }

    function test_gettingPriceInUsdFailsIfConfidenceIsTooHigh() external {
        skip(VALID_TIME_PERIOD);

        bytes[] memory updateData = new bytes[](1);
        uint64 invalidConf = 301e8;
        updateData[0] = pyth.createPriceFeedUpdateData(
            WETHUSD_PRICE_FEED_ID,
            price,
            invalidConf,
            expo,
            emaPrice,
            invalidConf,
            uint64(block.timestamp),
            uint64(block.timestamp)
        );
        pyth.updatePriceFeeds(updateData);

        uint256 scaleBy = 1e10;
        vm.expectRevert(
            abi.encodeWithSelector(
                IPythOracle.PythOracle__ConfidenceThresholdBreached.selector,
                invalidConf * scaleBy,
                uint64(price) * scaleBy
            )
        );
        pythOracle.getPriceInUsd(address(weth));
    }

    function test_gettingPriceInUsdSucceeds() external view {
        uint256 wethPrice = pythOracle.getPriceInUsd(address(weth));
        uint256 scaleBy = 1e10;

        assertEq(wethPrice, uint64(price) * scaleBy);
    }

    function test_getTargetDecimals() external view {
        uint8 targetDecimals = 18;

        assertEq(pythOracle.getTargetDecimals(), targetDecimals);
    }

    function test_getMaxAllowedConfidenceAsAPercentageOfPriceInBPs() external view {
        uint256 maxAllowedConfidenceAsAPercentageOfPriceInBPs = 1000;

        assertEq(
            pythOracle.getMaxAllowedConfidenceAsAPercentageOfPriceInBPs(), maxAllowedConfidenceAsAPercentageOfPriceInBPs
        );
    }

    function test_getPyth() external view {
        assertEq(pythOracle.getPyth(), address(pyth));
    }

    function test_getOracleConfig() external view {
        IPythOracle.OracleConfig memory actualOracleConfig = pythOracle.getOracleConfig(address(weth));

        assertEq(actualOracleConfig.priceFeedId, WETHUSD_PRICE_FEED_ID);
        assertEq(actualOracleConfig.stalenessThreshold, STALENESS_THRESHOLD);
    }
}
