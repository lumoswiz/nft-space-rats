// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {AsteroidMining} from "../src/staking/AsteroidMining.sol";
import {SpaceRats} from "../src/SpaceRats.sol";
import {Geode} from "../src/Geode.sol";
import {IridiumToken} from "../src/IridiumToken.sol";

import {IncentiveId} from "../src/staking/IncentiveId.sol";

import "../src/staking/Structs.sol";

contract AsteroidMiningTest is Test {
    using IncentiveId for IncentiveKey;

    AsteroidMining public asteroidMining;
    SpaceRats public spaceRats;
    Geode public geode;
    IridiumToken public iridium;

    uint8 constant PROTOCOL_FEE = 10; // 1%
    uint256 constant INCENTIVE_LENGTH = 30 days;
    uint256 constant INCENTIVE_AMOUNT = 1000 ether;
    uint256 constant GEODE_MINING_TIME = 21 days;
    uint256 constant BOND = 0.05 ether;

    uint256 internal constant COLLECTION_SIZE = 2000;
    uint256 internal constant MAX_BATCH_SIZE = 5;
    uint256 internal constant AMOUNT_FOR_WHITELIST = 1000;

    uint32 internal constant PUBLIC_SALE_START_TIME = 15_000_000;
    uint64 internal constant WHITELIST_PRICE = 1 ether;
    uint64 internal constant PUBLIC_PRICE = 2 ether;
    uint32 internal constant PUBLIC_SALE_KEY = 69420;

    address feeRecipient = makeAddr("Fee Recipient");
    address refundRecipient = makeAddr("Refund Recipient");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    IncentiveKey key;

    function setUp() public {
        spaceRats = new SpaceRats(
            MAX_BATCH_SIZE,
            COLLECTION_SIZE,
            COLLECTION_SIZE,
            AMOUNT_FOR_WHITELIST
        );

        geode = new Geode("");

        iridium = new IridiumToken();

        // Add alice and bob to SpaceRats whitelist mint
        spaceRats.addToWhitelist(alice, 10);
        spaceRats.addToWhitelist(bob, 10);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        startHoax(alice, alice);
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 1
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 2
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 3
        assertEq(spaceRats.balanceOf(alice), 3);
        vm.stopPrank();

        startHoax(bob, bob);
        spaceRats.whitelistMint{value: WHITELIST_PRICE}(); //tokenId 4
        assertEq(spaceRats.balanceOf(bob), 1);
        vm.stopPrank();

        asteroidMining = new AsteroidMining(
            ProtocolFeeInfo({recipient: feeRecipient, fee: PROTOCOL_FEE})
        );

        // setup incentive
        key = IncentiveKey({
            nft: spaceRats,
            rewardToken: iridium,
            rewardNft: geode,
            startTime: block.timestamp,
            endTime: block.timestamp + INCENTIVE_LENGTH,
            bondAmount: BOND,
            refundRecipient: refundRecipient
        });

        // Roles - address(this) for testing
        iridium.grantRole(iridium.MINTER_ROLE(), address(this));
        geode.grantRole(geode.MINTER_ROLE(), address(this));
        geode.grantRole(geode.BURNER_ROLE(), address(this));

        // Minting iridium
        iridium.mint(address(this), INCENTIVE_AMOUNT);
        iridium.approve(address(asteroidMining), type(uint256).max);

        // Create incentive
        asteroidMining.createIncentive(
            key,
            INCENTIVE_AMOUNT,
            GEODE_MINING_TIME
        );
    }

    function test_stake() public {
        startHoax(alice);
        uint256 beforeBalance = alice.balance;

        asteroidMining.stake{value: BOND}(key, 0);

        // verify staker
        bytes32 incentiveId = key.compute();
        assertEq(
            asteroidMining.stakers(incentiveId, 0),
            alice,
            "staker incorrect"
        );

        // verify stakerInfo
        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
            assertEq(startedStaking, block.timestamp, "startedStaking not now");
            assertEq(
                asteroidMining.miningTime(alice),
                0,
                "miningTime should be 0"
            );
        }

        // verify incentiveInfo
        {
            (
                ,
                ,
                uint64 numberOfStakedTokens,
                ,
                ,
                uint256 miningTimeForGeodes
            ) = asteroidMining.incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
            assertEq(
                miningTimeForGeodes,
                GEODE_MINING_TIME,
                "miningTimeForGeodes incorrectly set"
            );
        }

        // verify bond
        assertEqDecimal(
            beforeBalance - alice.balance,
            BOND,
            18,
            "didn't charge bond"
        );

        vm.warp(block.timestamp + 5 days);
        asteroidMining.stake{value: BOND}(key, 1);

        // verify miningTime
        assertEq(
            asteroidMining.miningTime(alice),
            5 days,
            "miningTime not 5 days"
        );

        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);

            assertEq(numberOfStakedTokens, 2, "Alice has staked 2 tokens");
            assertEq(
                startedStaking,
                block.timestamp,
                "startedStaking should update to now"
            );
        }
    }

    function test_stakeMultiple() public {
        startHoax(alice);
        uint256 numStaked = 2;
        StakeMultipleInput[] memory inputs = new StakeMultipleInput[](
            numStaked
        );
        inputs[0].key = key;
        inputs[0].nftId = 0;
        inputs[1].key = key;
        inputs[1].nftId = 1;

        uint256 beforeBalance = alice.balance;
        asteroidMining.stakeMultiple{value: BOND * numStaked}(inputs);

        bytes32 incentiveId = key.compute();

        // verify staker
        assertEq(
            asteroidMining.stakers(incentiveId, 0),
            alice,
            "staker 0 incorrect"
        );

        assertEq(
            asteroidMining.stakers(incentiveId, 1),
            alice,
            "staker 1 incorrect"
        );

        // verify stakerInfo
        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);
            assertEq(
                numberOfStakedTokens,
                numStaked,
                "numberOfStakedTokens not equal to numStaked"
            );
            assertEq(startedStaking, block.timestamp, "startedStaking not now");
            assertEq(
                asteroidMining.miningTime(alice),
                0,
                "miningTime should be 0"
            );
        }

        // verify incentiveInfo
        {
            (
                ,
                ,
                uint64 numberOfStakedTokens,
                ,
                ,
                uint256 miningTimeForGeodes
            ) = asteroidMining.incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 2, "numberOfStakedTokens not 2");
            assertEq(
                miningTimeForGeodes,
                GEODE_MINING_TIME,
                "miningTimeForGeodes incorrectly set"
            );
        }

        // verify bond
        assertEqDecimal(
            beforeBalance - alice.balance,
            BOND * 2,
            18,
            "didn't charge bond"
        );

        vm.warp(block.timestamp + 5 days);
        asteroidMining.stake{value: BOND}(key, 2);

        // verify staking info after 5 days

        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);

            assertEq(
                numberOfStakedTokens,
                numStaked + 1,
                "Alice has staked (numStaked + 1) tokens"
            );
            assertEq(
                startedStaking,
                block.timestamp,
                "startedStaking should update to now"
            );

            // verify miningTime
            assertEq(
                asteroidMining.miningTime(alice),
                numStaked * 5 days,
                "miningTime not 5 days"
            );
        }
    }

    function test_stakeAndUnstake() public {
        startHoax(alice);
        asteroidMining.stake{value: BOND}(key, 0);
        uint256 beforeBalance = alice.balance;
        asteroidMining.unstake(key, 0, alice);

        // verify staker
        bytes32 incentiveId = key.compute();
        assertEq(
            asteroidMining.stakers(incentiveId, 0),
            address(0),
            "staker incorrect"
        );

        // verify stakerInfo
        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);
            assertEq(numberOfStakedTokens, 0, "numberOfStakedTokens not 0");
            assertEq(startedStaking, 0, "startedStaking not 0");
            assertEq(
                asteroidMining.miningTime(alice),
                0,
                "miningTime should be 0"
            );
        }

        // verify incentiveInfo
        {
            (
                ,
                ,
                uint64 numberOfStakedTokens,
                ,
                ,
                uint256 miningTimeForGeodes
            ) = asteroidMining.incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 0, "numberOfStakedTokens not 0");
            assertEq(
                miningTimeForGeodes,
                GEODE_MINING_TIME,
                "miningTimeForGeodes incorrectly set"
            );
        }

        // verify bond
        assertEqDecimal(
            alice.balance - beforeBalance,
            BOND,
            18,
            "didn't receive bond"
        );
    }

    function test_stakeMultipleWaitAndUnstake() public {
        startHoax(alice);

        uint256 numStaked = 2;
        uint256 initialStakingTime = block.timestamp;
        StakeMultipleInput[] memory inputs = new StakeMultipleInput[](
            numStaked
        );
        inputs[0].key = key;
        inputs[0].nftId = 0;
        inputs[1].key = key;
        inputs[1].nftId = 1;

        asteroidMining.stakeMultiple{value: BOND * numStaked}(inputs);

        vm.warp(block.timestamp + 4 days);
        uint256 beforeBalance = alice.balance;

        asteroidMining.unstake(key, 0, alice);

        // verify staker
        bytes32 incentiveId = key.compute();
        assertEq(
            asteroidMining.stakers(incentiveId, 0),
            address(0),
            "staker incorrect"
        );

        // verify stakerInfo
        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
            assertEq(
                startedStaking,
                initialStakingTime,
                "startedStaking not initialStakingTime"
            );
            assertEq(
                asteroidMining.miningTime(alice),
                numStaked * (block.timestamp - initialStakingTime),
                "miningTime not set correctly"
            );
        }

        // verify incentiveInfo
        {
            (
                ,
                ,
                uint64 numberOfStakedTokens,
                ,
                ,
                uint256 miningTimeForGeodes
            ) = asteroidMining.incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
            assertEq(
                miningTimeForGeodes,
                GEODE_MINING_TIME,
                "miningTimeForGeodes incorrectly set"
            );
        }

        // verify bond
        assertEqDecimal(
            alice.balance - beforeBalance,
            BOND,
            18,
            "didn't receive bond"
        );
    }

    function test_stakeAndSlash() public {
        startHoax(alice);
        asteroidMining.stake{value: BOND}(key, 0);
        spaceRats.safeTransferFrom(alice, bob, 0);

        changePrank(bob);
        uint256 beforeBalance = bob.balance;
        asteroidMining.slashPaperHand(key, 0, bob);

        // verify staker
        bytes32 incentiveId = key.compute();
        assertEq(
            asteroidMining.stakers(incentiveId, 0),
            address(0),
            "staker incorrect"
        );

        // verify stakerInfo
        {
            (
                uint256 startedStaking,
                ,
                ,
                uint64 numberOfStakedTokens
            ) = asteroidMining.stakerInfos(incentiveId, alice);
            assertEq(numberOfStakedTokens, 0, "numberOfStakedTokens not 0");
            assertEq(startedStaking, 0, "startedStaking not 0");
            assertEq(asteroidMining.miningTime(alice), 0, "miningTime not 0");
        }

        // verify incentiveInfo
        {
            (
                ,
                ,
                uint64 numberOfStakedTokens,
                ,
                ,
                uint256 miningTimeForGeodes
            ) = asteroidMining.incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 0, "numberOfStakedTokens not 0");
            assertEq(
                miningTimeForGeodes,
                GEODE_MINING_TIME,
                "miningTimeForGeodes incorrectly set"
            );
        }

        // verify bond
        assertEqDecimal(
            bob.balance - beforeBalance,
            BOND,
            18,
            "didn't receive bond"
        );
    }
}
