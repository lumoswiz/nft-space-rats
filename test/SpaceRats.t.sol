// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IridiumToken} from "../src/IridiumToken.sol";
import {SpaceRats} from "../src/SpaceRats.sol";

contract SpaceRatsTest is Test {
    IridiumToken public iridium;
    SpaceRats public spaceRats;

    uint256 internal constant COLLECTION_SIZE = 2000;
    uint256 internal constant MAX_BATCH_SIZE = 5;
    uint256 internal constant AMOUNT_FOR_WHITELIST = 1000;
    uint256 internal constant AMOUNT_FOR_PUBLIC = 1000;

    uint32 internal constant PUBLIC_SALE_START_TIME = 15_000_000;
    uint64 internal constant WHITELIST_PRICE = 1 ether;
    uint64 internal constant PUBLIC_PRICE = 2 ether;
    uint32 internal constant PUBLIC_SALE_KEY = 69420;

    address alice = makeAddr("Alice");
    address rick = makeAddr("Rick");

    function setUp() public {
        startHoax(rick, rick);

        iridium = new IridiumToken();

        spaceRats = new SpaceRats(
            MAX_BATCH_SIZE,
            COLLECTION_SIZE,
            COLLECTION_SIZE,
            AMOUNT_FOR_WHITELIST
        );

        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();
    }
}
