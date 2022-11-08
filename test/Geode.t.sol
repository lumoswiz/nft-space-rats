// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Geode} from "../src/Geode.sol";
import {IridiumToken} from "../src/IridiumToken.sol";
import {MockVRFCoordinatorV2} from "chainlink-foundry/test/mocks/MockVRFCoordinatorV2.sol";
import {LinkToken} from "chainlink-foundry/test/mocks/LinkToken.sol";

contract GeodeUnitTest is Test {
    Geode public geode;
    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;
    IridiumToken public iridium;

    uint96 internal constant FUND_AMOUNT = 1_000 ether;

    // Blank init acceptable for testing
    uint64 subId;
    bytes32 keyHash; // gas lane

    address alice = makeAddr("Alice");

    function setUp() public {
        geode = new Geode("");

        // For testing purposes
        geode.grantRole(geode.MINTER_ROLE(), address(this));
    }

    function test_mintGeodes() public {
        assertEq(geode.tokenCounter(), 0);

        geode.mint(alice);

        assertEq(geode.tokenCounter(), 1);

        assertEq(geode.balanceOf(alice, 0), 1);
    }

    function test_defaultAdminRole() public {
        require(
            geode.hasRole(geode.DEFAULT_ADMIN_ROLE(), address(this)),
            "Account is not the DEFAULT_ADMIN_ROLE"
        );
    }

    function test_balanceOfBatchSingleAddress() public {
        uint256 mintTotal = 4;
        uint256[] memory ids = new uint256[](mintTotal);

        for (uint256 i; i < mintTotal; ++i) {
            geode.mint(alice);
            ids[i] = i;
        }

        uint256[] memory balances = geode.balanceOfBatchSingleAddress(
            alice,
            ids
        );

        emit log_array(balances);
    }
}
