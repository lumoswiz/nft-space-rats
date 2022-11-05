// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ProcessingPlant} from "../src/ProcessingPlant.sol";
import {Geode} from "../src/Geode.sol";
import {IridiumToken} from "../src/IridiumToken.sol";
import {MockVRFCoordinatorV2} from "chainlink-foundry/test/mocks/MockVRFCoordinatorV2.sol";
import {LinkToken} from "chainlink-foundry/test/mocks/LinkToken.sol";

contract ProcessingPlantTest is Test {
    ProcessingPlant public plant;
    IridiumToken public iridium;
    Geode public geode;
    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;

    uint96 internal constant FUND_AMOUNT = 1_000 ether;

    // Blank init acceptable for testing
    uint64 subId;
    bytes32 keyHash; // gas lane

    address alice = makeAddr("Alice");

    function setUp() public {
        iridium = new IridiumToken();
        geode = new Geode("");

        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

        plant = new ProcessingPlant(
            iridium,
            geode,
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash
        );

        vrfCoordinator.addConsumer(subId, address(plant));

        // For the purposes of testing
        geode.grantRole(geode.MINTER_ROLE(), address(this));

        assertEq(plant.processRound(), 0);
    }

    function test_processGeode() public {
        geode.mint(alice);

        startHoax(alice, alice);
        geode.setApprovalForAll(address(plant), true);
        plant.processGeode(0);

        assertEq(plant.processRound(), 1);
    }

    /// -----------------------------------------------------------------------
    /// Helper functions
    /// -----------------------------------------------------------------------

    //    function getWords(uint256 requestId)
    //        public
    //        view
    //        returns (uint256[] memory)
    //    {
    //        uint256[] memory words = new uint256[](geode.s_numWords());
    //        for (uint256 i = 0; i < geode.s_numWords(); i++) {
    //            words[i] = uint256(keccak256(abi.encode(requestId, i)));
    //        }
    //        return words;
    //    }
}
