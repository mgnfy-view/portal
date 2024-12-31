// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { MockPyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import { console } from "forge-std/console.sol";

import { IAssetRegistry } from "../../src/interfaces/IAssetRegistry.sol";

import { AssetRegistry } from "../../src/AssetRegistry.sol";
import { DestinationPortal } from "../../src/DestinationPortal.sol";
import { GlobalOwnable } from "../../src/GlobalOwnable.sol";
import { MultiAssetVault } from "../../src/MultiAssetVault.sol";
import { PythOracle } from "../../src/PythOracle.sol";
import { SourcePortal } from "../../src/SourcePortal.sol";

import { WrappedEther } from "./WrappedEther.sol";

abstract contract Base is TestHelperOz5 {
    address public owner;
    address public user1;
    address public user2;

    WrappedEther public weth;

    // Set up parameters for mock Pyth and the WETH/USD price feed
    uint256 public constant VALID_TIME_PERIOD = 1 hours;
    uint256 public SINGLE_PRICE_FEED_UPDATE_FEE = 0;
    MockPyth public pyth;
    bytes32 public constant WETHUSD_PRICE_FEED_ID = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
    int64 public price = 3000e8;
    uint64 public conf = 0;
    int32 public expo = -8;
    int64 emaPrice = price;
    uint64 emaConf = conf;

    // Layer Zero endpoint setup parameters
    uint8 public constant NUMBER_OF_ENDPOINTS = 2;
    uint8 public constant ENDPOINT_1 = 1;
    uint8 public constant ENDPOINT_2 = 2;

    GlobalOwnable public globalOwnable;
    AssetRegistry public assetRegistry;
    PythOracle public pythOracle;
    SourcePortal public sourcePortal;
    DestinationPortal public destinationPortal;
    MultiAssetVault public multiAssetVault;

    // WETH asset config
    uint256 public constant WETH_MINIMUM_COLLATERALISATION_RATIO = 1.5e18;
    uint16 public WETH_LIQUIDATION_REWARD_IN_BPS = 2_000;

    function setUp() public override {
        super.setUp();

        uint256 timeToSkip = 2 days;
        skip(timeToSkip);

        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        weth = new WrappedEther();

        pyth = new MockPyth(VALID_TIME_PERIOD, SINGLE_PRICE_FEED_UPDATE_FEE);

        setUpEndpoints(NUMBER_OF_ENDPOINTS, LibraryType.UltraLightNode);

        globalOwnable = new GlobalOwnable(owner);
        assetRegistry = new AssetRegistry(address(globalOwnable));
        pythOracle = new PythOracle(address(globalOwnable), address(pyth));
        sourcePortal = new SourcePortal(endpoints[ENDPOINT_1], address(globalOwnable));
        destinationPortal = new DestinationPortal(endpoints[ENDPOINT_2], owner);
        multiAssetVault =
            new MultiAssetVault(address(assetRegistry), address(pythOracle), address(sourcePortal), owner, owner);

        vm.startPrank(owner);
        address[] memory ofts = new address[](2);
        ofts[0] = address(sourcePortal);
        ofts[1] = address(destinationPortal);
        wireOApps(ofts);

        sourcePortal.initializeMultiAssetVaultAddress(address(multiAssetVault));

        assetRegistry.setAssetConfig(
            address(weth),
            IAssetRegistry.AssetConfig(WETH_MINIMUM_COLLATERALISATION_RATIO, WETH_LIQUIDATION_REWARD_IN_BPS)
        );
        vm.stopPrank();

        _updatePriceFeed();
    }

    function _updatePriceFeed() internal {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            WETHUSD_PRICE_FEED_ID, price, conf, expo, emaPrice, emaConf, uint64(block.timestamp), 0
        );

        pyth.updatePriceFeeds(updateData);
    }
}
