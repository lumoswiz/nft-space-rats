// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Geode} from "../src/Geode.sol";
import {MockVRFCoordinatorV2} from "chainlink-foundry/test/mocks/MockVRFCoordinatorV2.sol";
import {LinkToken} from "chainlink-foundry/test/mocks/LinkToken.sol";

interface IMintReward {
    function mintReward(address addr) external;
}

contract GeodeUnitTest is Test {
    Geode internal geode;
    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;

    uint96 internal constant FUND_AMOUNT = 1 ether;

    // Blank init acceptable for testing
    uint64 subId;
    bytes32 keyHash; // gas lane

    address alice = makeAddr("Alice");

    function setUp() public {
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();

        geode = new Geode(
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            ""
        );

        vrfCoordinator.addConsumer(subId, address(geode));
    }

    function test_interfaceId() public {
        bytes4 id = type(IMintReward).interfaceId;
        emit log_string(vm.toString(id));
    }

    function test_mint() public {
        geode.grantRole(geode.MINTER_ROLE(), address(this));

        assertEq(geode.tokenCounter(), 0);

        geode.mint(alice);

        assertEq(geode.tokenCounter(), 1);

        assertEq(geode.balanceOf(alice, 0), 1);
    }
}
