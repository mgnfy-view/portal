// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IGlobalOwnerChecker } from "../../src/interfaces/IGlobalOwnerChecker.sol";
import { IMultiAssetVault } from "../../src/interfaces/IMultiAssetVault.sol";
import { IPythOracle } from "../../src/interfaces/IPythOracle.sol";

import { AssetRegistry } from "../../src/AssetRegistry.sol";
import { GlobalOwnable } from "../../src/GlobalOwnable.sol";
import { MultiAssetVault } from "../../src/MultiAssetVault.sol";
import { PythOracle } from "../../src/PythOracle.sol";
import { SourcePortal } from "../../src/SourcePortal.sol";
import { Base } from "../utils/Base.sol";

contract InitializationTest is Base {
    function test_checkOwner() external view {
        assertEq(globalOwnable.owner(), owner);
        assertEq(assetRegistry.getGlobalOwner(), owner);
        assertEq(pythOracle.getGlobalOwner(), owner);
        assertEq(sourcePortal.getGlobalOwner(), owner);
    }

    function test_checkLiquidationPenaltyRecipientSetter() external view {
        assertEq(multiAssetVault.getLiquidationPenaltyRecipientSetter(), owner);
    }

    function test_checkLiquidationPenaltyRecipient() external view {
        assertEq(multiAssetVault.getLiquidationPenaltyRecipient(), owner);
    }

    function test_globalOwnableDeploymentFailsIfGlobalOwnerIsAddressZero() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new GlobalOwnable(address(0));
    }

    function test_assetRegistryDeploymentFailsIfGlobalOwnableIsAddressZero() external {
        vm.expectRevert(IGlobalOwnerChecker.GlobalOwnerChecker__AddressZero.selector);
        new AssetRegistry(address(0));
    }

    function test_pythOracleDeploymentFailsIfGlobalOwnableOrPythIsAddressZero() external {
        vm.expectRevert(IGlobalOwnerChecker.GlobalOwnerChecker__AddressZero.selector);
        new PythOracle(address(0), address(pyth));

        vm.expectRevert(IPythOracle.PythOracle__AddressZero.selector);
        new PythOracle(address(globalOwnable), address(0));
    }

    function test_sourcePortalDeploymentFailsIfLzEndpointOrGlobalOwnableIsAddressZero() external {
        vm.expectRevert();
        new SourcePortal(address(0), address(globalOwnable));

        vm.expectRevert(IGlobalOwnerChecker.GlobalOwnerChecker__AddressZero.selector);
        new SourcePortal(endpoints[ENDPOINT_1], address(0));
    }

    function test_destinationPortalDeploymentFailsIfLzEndpointOrGlobalOwnableIsAddressZero() external {
        vm.expectRevert();
        new SourcePortal(address(0), address(globalOwnable));

        vm.expectRevert(IGlobalOwnerChecker.GlobalOwnerChecker__AddressZero.selector);
        new SourcePortal(endpoints[ENDPOINT_2], address(0));
    }

    function test_multiAssetVaultDeploymentFailsIfConstructorArgsAreAddressZero() external {
        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        new MultiAssetVault(address(0), address(pyth), address(sourcePortal), address(owner), address(owner));

        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        new MultiAssetVault(address(assetRegistry), address(0), address(sourcePortal), address(owner), address(owner));

        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        new MultiAssetVault(address(assetRegistry), address(pyth), address(0), address(owner), address(owner));

        vm.expectRevert(IMultiAssetVault.MultiAssetVault__AddressZero.selector);
        new MultiAssetVault(address(assetRegistry), address(pyth), address(sourcePortal), address(0), address(owner));

        // The liquidation penalty recipient can be set to address 0 to disable protocol cut on liquidation rewards
    }
}
