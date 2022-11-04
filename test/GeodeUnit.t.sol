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
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        iridium = new IridiumToken();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        geode = new Geode(
            "",
            iridium,
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash
        );

        vrfCoordinator.addConsumer(subId, address(geode));

        geode.grantRole(geode.MINTER_ROLE(), address(this));
    }

    function test_mintGeodes() public {
        assertEq(geode.tokenCounter(), 0);

        geode.mint(alice);

        assertEq(geode.tokenCounter(), 1);

        assertEq(geode.balanceOf(alice, 0), 1);
    }

    function test_canCrackGeode() public {
        geode.mint(alice);

        startHoax(alice, alice);

        uint256 requestId = geode.crackGeode(0);
    }

    function test_canFulfillRandomness() public {
        geode.mint(alice);

        startHoax(alice);

        uint256 requestId = geode.crackGeode(0);
        uint256[] memory words = getWords(requestId);
        vrfCoordinator.fulfillRandomWords(requestId, address(geode));

        emit log_array(words);
    }

    function test_earnIridiumFromCrackingGeode() public {
        geode.mint(alice);

        startHoax(alice, alice);
        uint256 iridiumBefore = iridium.balanceOf(alice);

        uint256 requestId = geode.crackGeode(0);
        uint256[] memory words = getWords(requestId);
        vrfCoordinator.fulfillRandomWords(requestId, address(geode));

        assertEq(iridium.balanceOf(alice) - iridiumBefore, 10e18);
    }

    function test_canUpdateIridiumImplementation() public {
        address initialImplementation = address(geode.iridium());

        IridiumToken iridium_ = new IridiumToken();

        geode.updateIridiumImplementation(iridium_);

        assertTrue(initialImplementation != address(geode.iridium()));
    }

    function test_cannotUpdateIridiumImplementationIfNotAdmin() public {
        startHoax(alice, alice);

        address initialImplementation = address(geode.iridium());

        IridiumToken iridium_ = new IridiumToken();

        vm.expectRevert();
        geode.updateIridiumImplementation(iridium_);

        assertTrue(initialImplementation == address(geode.iridium()));
    }

    /// -----------------------------------------------------------------------
    /// Helper functions
    /// -----------------------------------------------------------------------

    function getWords(uint256 requestId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory words = new uint256[](geode.s_numWords());
        for (uint256 i = 0; i < geode.s_numWords(); i++) {
            words[i] = uint256(keccak256(abi.encode(requestId, i)));
        }
        return words;
    }
}
