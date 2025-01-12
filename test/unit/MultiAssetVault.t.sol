// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { console } from "forge-std/console.sol";

import { IGlobalOwnerChecker } from "../../src/interfaces/IGlobalOwnerChecker.sol";
import { IMultiAssetVault } from "../../src/interfaces/IMultiAssetVault.sol";

import { Base } from "../utils/Base.sol";

contract MultiAssetVaultTest is Base {
    function test_settingNewLiquidationRecipientSetterRevertsIfCallerIsNotLiquidationRecipientSetter() external {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiAssetVault.MultiAssetVault_NotLiquidationPenaltyRecipientSetter.selector, user1, owner
            )
        );
        multiAssetVault.setLiquidationPenaltyRecipientSetter(user1);
        vm.stopPrank();
    }

    function test_settingNewLiquidationRecipientSetterRevertsIfLiquidationRecipientSetterIsAddressZero() external {
        vm.startPrank(owner);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        multiAssetVault.setLiquidationPenaltyRecipientSetter(address(0));
        vm.stopPrank();
    }

    function test_settingNewLiquidationRecipientSetterSucceeds() external {
        vm.startPrank(owner);
        multiAssetVault.setLiquidationPenaltyRecipientSetter(user1);
        vm.stopPrank();

        assertEq(multiAssetVault.getLiquidationPenaltyRecipientSetter(), user1);
    }

    function test_settingNewLiquidationRecipientSetterEmitsEvent() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IMultiAssetVault.NewLiquidationPenaltyRecipientSetterSet(user1);
        multiAssetVault.setLiquidationPenaltyRecipientSetter(user1);
        vm.stopPrank();
    }

    function test_settingNewLiquidationRecipientRevertsIfCallerIsNotLiquidationRecipientSetter() external {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiAssetVault.MultiAssetVault_NotLiquidationPenaltyRecipientSetter.selector, user1, owner
            )
        );
        multiAssetVault.setLiquidationPenaltyRecipient(user1);
        vm.stopPrank();
    }

    function test_settingNewLiquidationRecipientSucceeds() external {
        vm.startPrank(owner);
        multiAssetVault.setLiquidationPenaltyRecipient(user1);
        vm.stopPrank();

        assertEq(multiAssetVault.getLiquidationPenaltyRecipient(), user1);
    }

    function test_settingNewLiquidationRecipientEmitsEvent() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IMultiAssetVault.NewLiquidationPenaltyRecipientSet(user1);
        multiAssetVault.setLiquidationPenaltyRecipient(user1);
        vm.stopPrank();
    }

    function test_depositingCollateralFailsIfAssetIsNotWhitelisted() external {
        address asset = makeAddr("asset");
        uint256 amount = 100e18;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(IMultiAssetVault.MultiAssetVault__AssetNotWhitelisted.selector, asset));
        multiAssetVault.depositCollateral(asset, amount, user1);
        vm.stopPrank();
    }

    function test_depositingCollateralFailsIfAmountIsZero() external {
        uint256 amount = 0;

        vm.startPrank(user1);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AmountZero.selector);
        multiAssetVault.depositCollateral(address(weth), amount, user1);
        vm.stopPrank();
    }

    function test_depositingCollateralFailsIfForIsAddressZero() external {
        uint256 amount = 100e18;

        vm.startPrank(user1);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        multiAssetVault.depositCollateral(address(weth), amount, address(0));
        vm.stopPrank();
    }

    function test_depositingCollateralSucceeds() external {
        uint256 amount = 1e18;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        vm.stopPrank();
        _depositCollateral(user1, address(weth), amount, user1);

        IMultiAssetVault.Position memory position = multiAssetVault.getPosition(user1, address(weth));

        assertEq(position.amountDeposited, amount);
        assertEq(position.amountMinted, 0);
        assertEq(weth.balanceOf(address(multiAssetVault)), amount);
    }

    function test_depositingCollateralForSucceeds() external {
        uint256 amount = 1e18;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        vm.stopPrank();

        _depositCollateral(user1, address(weth), amount, user2);

        IMultiAssetVault.Position memory position = multiAssetVault.getPosition(user2, address(weth));

        assertEq(position.amountDeposited, amount);
        assertEq(position.amountMinted, 0);
        assertEq(weth.balanceOf(address(multiAssetVault)), amount);
    }

    function test_depositingCollateralEmitsEvent() external {
        uint256 amount = 1e18;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        weth.approve(address(weth), amount);
        vm.expectEmit(true, true, true, true);
        emit IMultiAssetVault.AmountDeposited(user1, address(weth), amount, user1);
        multiAssetVault.depositCollateral(address(weth), amount, user1);
        vm.stopPrank();
    }

    function test_withdrawingCollateralFailsIfAssetIsNotWhitelisted() external {
        address asset = makeAddr("asset");
        uint256 amount = 100e18;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(IMultiAssetVault.MultiAssetVault__AssetNotWhitelisted.selector, asset));
        multiAssetVault.withdrawCollateral(asset, amount, user1);
        vm.stopPrank();
    }

    function test_withdrawingCollateralFailsIfAmountIsZero() external {
        uint256 amount = 0;

        vm.startPrank(user1);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AmountZero.selector);
        multiAssetVault.withdrawCollateral(address(weth), amount, user1);
        vm.stopPrank();
    }

    function test_withdrawingCollateralFailsIfToIsAddressZero() external {
        uint256 amount = 100e18;

        vm.startPrank(user1);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        multiAssetVault.withdrawCollateral(address(weth), amount, address(0));
        vm.stopPrank();
    }

    function test_withdrawingCollateralFailsIfPositionIsUnHealthy() external {
        uint256 amount = 1e18;
        uint256 portalAmount = 1500e6;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        vm.stopPrank();
        _depositCollateral(user1, address(weth), amount, user1);

        vm.startPrank(user1);
        multiAssetVault.mintPortal(address(weth), portalAmount, user1);
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__MinimumCollateralisationRatioBreached.selector);
        multiAssetVault.withdrawCollateral(address(weth), amount, user1);
        vm.stopPrank();
    }

    function test_withdrawingCollateralSucceeds() external {
        uint256 amount = 1e18;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        vm.stopPrank();
        _depositCollateral(user1, address(weth), amount, user1);

        vm.startPrank(user1);
        multiAssetVault.withdrawCollateral(address(weth), amount, user1);
        vm.stopPrank();

        IMultiAssetVault.Position memory position = multiAssetVault.getPosition(user2, address(weth));

        assertEq(position.amountDeposited, 0);
        assertEq(position.amountMinted, 0);
        assertEq(weth.balanceOf(user1), amount);
    }

    function test_withdrawingCollateralEmitsEvent() external {
        uint256 amount = 1e18;

        _dealNativeTokens(user1, amount);

        vm.startPrank(user1);
        weth.deposit{ value: amount }();
        vm.stopPrank();
        _depositCollateral(user1, address(weth), amount, user1);

        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit IMultiAssetVault.AmountWithdrawn(user1, address(weth), amount, user1);
        multiAssetVault.withdrawCollateral(address(weth), amount, user1);
        vm.stopPrank();
    }
}
