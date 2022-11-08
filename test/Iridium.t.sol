// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IridiumToken} from "../src/IridiumToken.sol";

contract IridiumUnitTest is Test {
    IridiumToken internal iridium;

    function setUp() public {
        iridium = new IridiumToken();
    }

    function test_roles() public {
        require(
            iridium.hasRole(iridium.DEFAULT_ADMIN_ROLE(), address(this)),
            "Account is not the DEFAULT_ADMIN_ROLE"
        );

        iridium.grantRole(iridium.MINTER_ROLE(), address(this));

        require(
            iridium.hasRole(iridium.MINTER_ROLE(), address(this)),
            "Account is not the MINTER_ROLE"
        );
    }

    function test_mint() public {
        uint256 MINT_UNITS = 1_000_000e18;

        iridium.grantRole(iridium.MINTER_ROLE(), address(this));

        assertEq(iridium.totalSupply(), 0);
        assertEq(iridium.balanceOf(address(this)), 0);

        uint256 balanceBefore = iridium.balanceOf(address(this));

        iridium.mint(address(this), MINT_UNITS);

        assertEq(iridium.totalSupply(), MINT_UNITS);
        assertEq(iridium.balanceOf(address(this)) - balanceBefore, MINT_UNITS);
    }
}
