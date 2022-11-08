// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {SpaceRats} from "../src/SpaceRats.sol";
import {IridiumToken} from "../src/IridiumToken.sol";
import {Geode} from "../src/Geode.sol";
import {AsteroidMining} from "../src/staking/AsteroidMining.sol";
import {ProcessingPlant} from "../src/ProcessingPlant.sol";

import {MockVRFCoordinatorV2} from "chainlink-foundry/test/mocks/MockVRFCoordinatorV2.sol";
import {LinkToken} from "chainlink-foundry/test/mocks/LinkToken.sol";

import {IncentiveId} from "../src/staking/IncentiveId.sol";
import "../src/staking/Structs.sol";

contract SpaceRatsIntegrationTest is Test {
    // Contracts
    SpaceRats public spaceRats;
    IridiumToken public iridium;
    Geode public geode;
    AsteroidMining public asteroidMining;
    ProcessingPlant public plant;

    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;

    // Addresses
    address multiSig = makeAddr("Space Rats Multi Sig");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    // Space Rats mint details
    uint256 internal constant COLLECTION_SIZE = 2000;
    uint256 internal constant MAX_BATCH_SIZE = 5;
    uint256 internal constant AMOUNT_FOR_WHITELIST = 1000;
    uint256 internal constant AMOUNT_FOR_PUBLIC = 1000;

    uint32 internal constant PUBLIC_SALE_START_TIME = 15_000_000;
    uint64 internal constant WHITELIST_PRICE = 1 ether;
    uint64 internal constant PUBLIC_PRICE = 2 ether;
    uint32 internal constant PUBLIC_SALE_KEY = 1_000;

    // Asteroid Mining variables
    uint256 constant INCENTIVE_LENGTH = 30 days;
    uint256 constant INCENTIVE_AMOUNT = 1000 ether;
    uint8 constant PROTOCOL_FEE = 10; // 1%
    uint256 constant GEODE_MINING_TIME = 21 days;
    uint256 constant BOND = 0.05 ether;
    uint256 constant MAX_ERROR_PERCENT = 1e9; // 10**-9

    IncentiveKey key;

    // ProcessingPlant chainlink VRF V2 variables
    uint96 internal constant FUND_AMOUNT = 1_000 ether;
    uint256 internal constant IRIDIUM_REWARD_AMOUNT = 10e18;
    uint64 subId;
    bytes32 keyHash;

    function setUp() public {
        startHoax(multiSig, multiSig);

        // deploy SpaceRats
        spaceRats = new SpaceRats(
            MAX_BATCH_SIZE,
            COLLECTION_SIZE,
            COLLECTION_SIZE,
            AMOUNT_FOR_WHITELIST
        );

        // deploy Iridium
        iridium = new IridiumToken();

        // deploy Geode
        geode = new Geode("");

        // deploy MockVRFCoordinatorV2: setup subId and fund it
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        // deploy ProcessingPlant
        plant = new ProcessingPlant(
            iridium,
            geode,
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash
        );

        // deploy AsteroidMining
        asteroidMining = new AsteroidMining(
            ProtocolFeeInfo({recipient: multiSig, fee: PROTOCOL_FEE})
        );

        // setup SpaceRats mint
        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        // 10 whitelist spots to alice and bob
        spaceRats.addToWhitelist(alice, 10);
        spaceRats.addToWhitelist(bob, 10);

        // assign roles
        geode.grantRole(geode.MINTER_ROLE(), address(asteroidMining));
        geode.grantRole(geode.BURNER_ROLE(), address(plant));

        iridium.grantRole(iridium.MINTER_ROLE(), multiSig); // for creating incentives
        iridium.grantRole(iridium.MINTER_ROLE(), address(asteroidMining));
        iridium.grantRole(iridium.MINTER_ROLE(), address(plant));

        // set up AsteroidMining
        iridium.mint(multiSig, INCENTIVE_AMOUNT);
        iridium.approve(address(asteroidMining), type(uint256).max); // max approval for testing

        vm.stopPrank();

        // whitelist mint for alice and bob
        startHoax(alice, alice);
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 0
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 1
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 2
        assertEq(spaceRats.balanceOf(alice), 3);
        vm.stopPrank();

        startHoax(bob, bob);
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 3
        assertEq(spaceRats.balanceOf(bob), 1);
        vm.stopPrank();

        startHoax(multiSig, multiSig);
        // AsteroidMining: create incentive
        key = IncentiveKey({
            nft: spaceRats,
            rewardToken: iridium,
            rewardNft: geode,
            startTime: block.timestamp,
            endTime: block.timestamp + INCENTIVE_LENGTH,
            bondAmount: BOND,
            refundRecipient: multiSig
        });

        asteroidMining.createIncentive(
            key,
            INCENTIVE_AMOUNT,
            GEODE_MINING_TIME
        );

        // set up ProcessingPlant
        plant.setIridiumRewardAmount(IRIDIUM_REWARD_AMOUNT);
        vrfCoordinator.addConsumer(subId, address(plant));

        vm.stopPrank();
    }

    function test_stakeWaitClaimRewards() public {
        startHoax(alice, alice);

        asteroidMining.stake{value: BOND}(key, 0);
    }
}
