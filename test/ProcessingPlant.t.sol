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

    function testCorrectness_processGeode() public {
        geode.mint(alice);

        startHoax(alice, alice);
        geode.setApprovalForAll(address(plant), true);

        uint256 tokenId = 0;
        plant.processGeode(tokenId);

        uint256 processRound = plant.processRound();

        // check processRound incremenets
        assertEq(processRound, 1);

        // check that ProcessingInfo set correctly
        (uint256 startTime, uint256 endTime) = plant.roundInfo(processRound);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 days);

        // check that roundTokenIds updates correctly (checking array index 0)
        uint256 id = plant.roundTokenIds(processRound, 0);
        assertEq(id, tokenId);

        // check that rewardsFor updates correctly
        assertEq(alice, plant.rewardsFor(tokenId));
    }

    function testCorrectness_newProcessRound() public {
        uint256 mintTotal = 4;

        for (uint256 i; i < mintTotal; ++i) {
            geode.mint(alice);
        }

        startHoax(alice, alice);
        geode.setApprovalForAll(address(plant), true);

        // tokenId = 0 @ index location 0 for processRound = 1
        plant.processGeode(0);
        // tokenId = 2 @ index location 1 for processRound = 1
        plant.processGeode(2);

        uint256 processRound = plant.processRound();

        assertEq(processRound, 1);
        assertEq(plant.roundTokenIds(processRound, 0), 0);
        assertEq(plant.roundTokenIds(processRound, 1), 2);

        // warp forward by 4 days (> 3 days for each processRound)
        vm.warp(block.timestamp + 4 days);

        // tokenId = 1 @ index location 0 for processRound = 2
        plant.processGeode(1);
        // tokenId = 3 @ index location 1 for processRound = 2
        plant.processGeode(3);

        processRound = plant.processRound();

        assertEq(plant.roundTokenIds(processRound, 0), 1);
        assertEq(plant.roundTokenIds(processRound, 1), 3);
    }

    function test_canRequestRandomness() public {
        geode.mint(alice);
        geode.mint(alice);

        startHoax(alice, alice);

        geode.setApprovalForAll(address(plant), true);
        plant.processGeode(0);
        plant.processGeode(1);

        uint256 processRound = plant.processRound();

        vm.stopPrank();

        // processRound 1 ends @ 3 days
        vm.warp(block.timestamp + 4 days);

        uint256 requestId = plant.requestRandomness(processRound);
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
