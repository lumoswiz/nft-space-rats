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

        spaceRats.addToWhitelist(alice, AMOUNT_FOR_WHITELIST);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        startHoax(alice, alice);
        spaceRats.whitelistMint{value: WHITELIST_PRICE}();
        vm.stopPrank();

        assertEq(spaceRats.balanceOf(alice), 1);

        asteroidMining = new AsteroidMining(
            ProtocolFeeInfo({recipient: feeRecipient, fee: PROTOCOL_FEE})
        );

        // setup incentive
        key = IncentiveKey({
            nft: spaceRats,
            rewardToken: iridium,
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
        asteroidMining.createIncentive(key, INCENTIVE_AMOUNT);

        // Mint NFTs
        geode.mint(alice); // tokenId = 0
        geode.mint(alice); // tokenId = 1
        geode.mint(bob); // tokenId = 2
        geode.mint(bob); // tokenId = 3
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
            (, , uint64 numberOfStakedTokens) = asteroidMining.stakerInfos(
                incentiveId,
                alice
            );
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
        }

        // verify incentiveInfo
        {
            (, , uint64 numberOfStakedTokens, , ) = asteroidMining
                .incentiveInfos(incentiveId);
            assertEq(numberOfStakedTokens, 1, "numberOfStakedTokens not 1");
        }

        // verify bond
        assertEqDecimal(
            beforeBalance - alice.balance,
            BOND,
            18,
            "didn't charge bond"
        );
    }
}
