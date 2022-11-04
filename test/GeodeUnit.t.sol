// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Geode} from "../src/Geode.sol";

interface IMintReward {
    function mintReward(address addr) external;
}

contract GeodeUnitTest is Test {
    Geode internal geode;

    address alice = makeAddr("Alice");

    function setUp() public {
        geode = new Geode("");
    }

    function test_interfaceId() public {
        bytes4 id = type(IMintReward).interfaceId;
        emit log_string(vm.toString(id));
    }

    function test_mint() public {
        geode.grantRole(geode.MINTER_ROLE(), address(this));

        assertEq(geode._tokenIds(), 0);

        geode.mint(alice);

        assertEq(geode._tokenIds(), 1);

        assertEq(geode.balanceOf(alice, 0), 1);
    }
}
