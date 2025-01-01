// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IAssetRegistry } from "../../src/interfaces/IAssetRegistry.sol";
import { IGlobalOwnerChecker } from "../../src/interfaces/IGlobalOwnerChecker.sol";

import { AssetRegistry } from "../../src/AssetRegistry.sol";
import { Base } from "../utils/Base.sol";

contract AssetRegistryTest is Base {
    // Mainnet wBTC address
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    uint256 public constant WBTC_MINIMUM_COLLATERALISATION_RATIO = 2e18;
    uint16 public WBTC_LIQUIDATION_REWARD_IN_BPS = 3_000;

    function test_settingAssetConfigFailsIfCallerIsNotGlobalOwner() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(IGlobalOwnerChecker.GlobalOwnerChecker__NotOwner.selector, user1, owner));
        assetRegistry.setAssetConfig(
            WBTC, IAssetRegistry.AssetConfig(WBTC_MINIMUM_COLLATERALISATION_RATIO, WBTC_LIQUIDATION_REWARD_IN_BPS)
        );
        vm.stopPrank();
    }

    function test_settingAssetConfigFailsIfAssetIsAddressZero() external {
        vm.startPrank(owner);
        vm.expectRevert(IAssetRegistry.AssetRegistry__AddressZero.selector);
        assetRegistry.setAssetConfig(
            address(0), IAssetRegistry.AssetConfig(WBTC_MINIMUM_COLLATERALISATION_RATIO, WBTC_LIQUIDATION_REWARD_IN_BPS)
        );
        vm.stopPrank();
    }

    function test_settingAssetConfigFailsIfMinCollateralisationRatioIsZero() external {
        IAssetRegistry.AssetConfig memory assetConfig = IAssetRegistry.AssetConfig(0, WBTC_LIQUIDATION_REWARD_IN_BPS);

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetRegistry__InvalidAssetConfig.selector, WBTC, assetConfig)
        );
        assetRegistry.setAssetConfig(WBTC, assetConfig);
        vm.stopPrank();
    }

    function test_settingAssetConfigFailsIfLiquidationRewardInBPsIsZero() external {
        IAssetRegistry.AssetConfig memory assetConfig =
            IAssetRegistry.AssetConfig(WBTC_MINIMUM_COLLATERALISATION_RATIO, 0);

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetRegistry__InvalidAssetConfig.selector, WBTC, assetConfig)
        );
        assetRegistry.setAssetConfig(WBTC, assetConfig);
        vm.stopPrank();
    }

    function test_settingAssetConfigSucceeds() external {
        IAssetRegistry.AssetConfig memory assetConfig =
            IAssetRegistry.AssetConfig(WBTC_MINIMUM_COLLATERALISATION_RATIO, WBTC_LIQUIDATION_REWARD_IN_BPS);

        vm.startPrank(owner);
        assetRegistry.setAssetConfig(WBTC, assetConfig);
        vm.stopPrank();

        IAssetRegistry.AssetConfig memory actualAssetConfig = assetRegistry.getAssetConfig(WBTC);

        assertTrue(assetRegistry.isAssetWhitelisted(WBTC));
        assertEq(actualAssetConfig.minimumCollateralisationRatio, WBTC_MINIMUM_COLLATERALISATION_RATIO);
        assertEq(actualAssetConfig.liquidationRewardInBPs, WBTC_LIQUIDATION_REWARD_IN_BPS);
    }

    function test_settingAssetConfigEmitsEvent() external {
        IAssetRegistry.AssetConfig memory assetConfig =
            IAssetRegistry.AssetConfig(WBTC_MINIMUM_COLLATERALISATION_RATIO, WBTC_LIQUIDATION_REWARD_IN_BPS);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAssetRegistry.AssetConfigSet(WBTC, assetConfig);
        assetRegistry.setAssetConfig(WBTC, assetConfig);
        vm.stopPrank();
    }
}
