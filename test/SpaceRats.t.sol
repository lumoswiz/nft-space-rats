// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IridiumToken} from "../src/IridiumToken.sol";
import {SpaceRats} from "../src/SpaceRats.sol";
import {ERC721A} from "../src/ERC721A/ERC721A.sol";

contract SpaceRatsUnitTest is Test {
    using stdStorage for StdStorage;

    SpaceRats public spaceRats;

    uint256 internal constant COLLECTION_SIZE = 2000;
    uint256 internal constant MAX_BATCH_SIZE = 5;
    uint256 internal constant AMOUNT_FOR_WHITELIST = 1000;
    uint256 internal constant AMOUNT_FOR_PUBLIC = 1000;

    uint32 internal constant PUBLIC_SALE_START_TIME = 15_000_000;
    uint64 internal constant WHITELIST_PRICE = 1 ether;
    uint64 internal constant PUBLIC_PRICE = 2 ether;
    uint32 internal constant PUBLIC_SALE_KEY = 69_420;

    address alice = makeAddr("Alice");
    address rick = makeAddr("Rick");

    function setUp() public {
        startHoax(rick, rick);

        spaceRats = new SpaceRats(
            MAX_BATCH_SIZE,
            COLLECTION_SIZE,
            COLLECTION_SIZE,
            AMOUNT_FOR_WHITELIST
        );
    }

    /// -----------------------------------------------------------------------
    /// Testing: SpaceRats (Correctness)
    /// -----------------------------------------------------------------------

    /// @notice Can't deploy SpaceRats with `amountForPublicAndWhitelist_` greater than `collectionSize_`
    function test_deploy() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SpaceRats.SpaceRats__LargerCollectionSizeNeeded.selector
            )
        );
        spaceRats = new SpaceRats(
            MAX_BATCH_SIZE,
            COLLECTION_SIZE,
            COLLECTION_SIZE + 1,
            AMOUNT_FOR_WHITELIST
        );
    }

    /// @notice Test correctness of setPublicSaleKey, other saleConfig variables to remain equal to zero.
    function test_setPublicSaleKey() public {
        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        (
            uint32 publicSaleStartTime,
            uint64 whitelistPrice,
            uint64 publicPrice,
            uint32 publicSaleKey
        ) = spaceRats.saleConfig();

        assertEq(publicSaleKey, PUBLIC_SALE_KEY);

        // Other saleConfig variables should not be initialised.
        assertEq(publicSaleStartTime, 0);
        assertEq(whitelistPrice, 0);
        assertEq(publicPrice, 0);
    }

    /// @notice Test correctness of setupSaleInfo (fuzzed).
    function test_setupSaleInfo(
        uint32 publicSaleStartTime_,
        uint64 whitelistPrice_,
        uint64 publicPrice_,
        uint32 publicSaleKey_
    ) public {
        vm.assume(publicSaleStartTime_ > block.timestamp);
        vm.assume(whitelistPrice_ > 0);
        vm.assume(publicPrice_ > 0);

        spaceRats.setPublicSaleKey(publicSaleKey_);

        spaceRats.setupSaleInfo(
            publicSaleStartTime_,
            whitelistPrice_,
            publicPrice_,
            publicSaleKey_
        );

        (
            uint32 publicSaleStartTime,
            uint64 whitelistPrice,
            uint64 publicPrice,
            uint32 publicSaleKey
        ) = spaceRats.saleConfig();

        assertEq(publicSaleStartTime, publicSaleStartTime_);
        assertEq(whitelistPrice, whitelistPrice_);
        assertEq(publicPrice, publicPrice_);
        assertEq(publicSaleKey, publicSaleKey_);
    }

    /// @notice Test correctness of public sale mint (correct msg.value, public sale key and batch size).
    function test_publicSaleMint() public {
        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(alice, alice);
        vm.warp(PUBLIC_SALE_START_TIME);

        uint256 aliceEthBalanceBefore = alice.balance;
        uint256 ratsEthBalanceBefore = address(spaceRats).balance;

        assertEq(spaceRats.numberMinted(alice), 0);

        spaceRats.publicSaleMint{value: 3 * PUBLIC_PRICE + 0.1 ether}(
            3,
            PUBLIC_SALE_KEY
        );

        assertEq(aliceEthBalanceBefore - 3 * PUBLIC_PRICE, alice.balance);

        assertEq(spaceRats.numberMinted(alice), 3);

        assertEq(
            stdMath.delta(address(spaceRats).balance, ratsEthBalanceBefore),
            3 * PUBLIC_PRICE
        );
    }

    /// @notice Test correctness of public sale mint (incorrect msg.value).
    function test_publicSaleMintIncorrectMsgValue() public {
        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(alice, alice);
        vm.warp(PUBLIC_SALE_START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(SpaceRats.SpaceRats__SendMoreEth.selector)
        );
        spaceRats.publicSaleMint{value: 0.1 ether}(3, PUBLIC_SALE_KEY);
    }

    /// @notice Test correctness of public sale mint (incorrect publicSaleKey).
    function test_publicSaleMintIncorrectPublicSaleKey() public {
        uint32 INCORRECT_KEY = 1;

        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(alice, alice);
        vm.warp(PUBLIC_SALE_START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                SpaceRats.SpaceRats__IncorrectPublicSaleKey.selector
            )
        );
        spaceRats.publicSaleMint{value: 3 * PUBLIC_PRICE + 0.1 ether}(
            3,
            INCORRECT_KEY
        );
    }

    /// @notice Test correctness of public sale mint (incorrect batch size).
    /// Caught a mistake with erorrs in publicSaleMint.
    /// expectRevert enabled me to catch it quickly vs. use of testFail.
    function test_publicSaleMintBatchSizeTooLarge() public {
        uint256 BATCH_SIZE = 20;

        spaceRats.setPublicSaleKey(PUBLIC_SALE_KEY);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(alice, alice);
        vm.warp(PUBLIC_SALE_START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                SpaceRats.SpaceRats__CannotMintThisMany.selector
            )
        );
        spaceRats.publicSaleMint{value: BATCH_SIZE * PUBLIC_PRICE + 0.1 ether}(
            BATCH_SIZE,
            PUBLIC_SALE_KEY
        );
    }

    function test_seedWhitelist() public {
        (
            address[] memory addresses,
            uint256[] memory numSlots
        ) = createWhitelistedUsers(200, 5);

        spaceRats.seedWhitelist(addresses, numSlots);
    }

    function test_whitelistMintUsingSeedWhitelist() public {
        (
            address[] memory whitelistedAddresses,
            uint256[] memory numSlots
        ) = createWhitelistedUsers(200, 5);

        spaceRats.seedWhitelist(whitelistedAddresses, numSlots);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        address whitelistedUser = whitelistedAddresses[0];

        startHoax(whitelistedUser, whitelistedUser);

        for (uint256 i; i < numSlots[0]; ++i) {
            spaceRats.whitelistMint{value: WHITELIST_PRICE}();
        }

        uint256 numSlotsRemaining = stdstore
            .target(address(spaceRats))
            .sig("allowlist(address)")
            .with_key(whitelistedUser)
            .read_uint();

        // After minting 5 times, remaining mint slots in WL should be 0.
        assertEq(numSlotsRemaining, 0);
    }

    function test_whitelistMintUsingAddToWhitelist() public {
        address whitelistedUser = makeAddr("User");
        uint256 numSlots = 5;

        spaceRats.addToWhitelist(whitelistedUser, numSlots);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(whitelistedUser, whitelistedUser);

        for (uint256 i; i < numSlots; ++i) {
            spaceRats.whitelistMint{value: WHITELIST_PRICE}();
        }

        uint256 numSlotsRemaining = stdstore
            .target(address(spaceRats))
            .sig("allowlist(address)")
            .with_key(whitelistedUser)
            .read_uint();

        // After minting 5 times, remaining mint slots in WL should be 0.
        assertEq(numSlotsRemaining, 0);
    }

    function test_whitelistMintNotBegun() public {
        address whitelistedUser = makeAddr("User");
        uint256 numSlots = 5;

        spaceRats.addToWhitelist(whitelistedUser, numSlots);
        vm.stopPrank();

        startHoax(whitelistedUser, whitelistedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                SpaceRats.SpaceRats__WhitelistMintHasNotBegun.selector
            )
        );
        spaceRats.whitelistMint{value: WHITELIST_PRICE}();
    }

    function test_whitelistMintNotOnWhitelist() public {
        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        // Alice is not on the whitelist
        startHoax(alice, alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SpaceRats.SpaceRats__NotEligibleForWhitelistMint.selector
            )
        );
        spaceRats.whitelistMint{value: WHITELIST_PRICE}();
    }

    function test_ownerWithdrawAfterMint() public {
        uint256 spaceRatsBalanceBeforeMint = address(spaceRats).balance;
        uint256 rickBalanceBeforeMint = rick.balance;

        address whitelistedUser = makeAddr("User");

        spaceRats.addToWhitelist(whitelistedUser, AMOUNT_FOR_WHITELIST);

        spaceRats.setupSaleInfo(
            PUBLIC_SALE_START_TIME,
            WHITELIST_PRICE,
            PUBLIC_PRICE,
            PUBLIC_SALE_KEY
        );

        vm.stopPrank();

        startHoax(whitelistedUser, whitelistedUser);
        for (uint256 i; i < AMOUNT_FOR_WHITELIST; ++i) {
            spaceRats.whitelistMint{value: WHITELIST_PRICE}();
        }
        vm.stopPrank();

        startHoax(alice, alice);
        vm.warp(PUBLIC_SALE_START_TIME);
        uint256 NUMBER_MINTED = 3;

        spaceRats.publicSaleMint{value: NUMBER_MINTED * PUBLIC_PRICE}(
            NUMBER_MINTED,
            PUBLIC_SALE_KEY
        );
        vm.stopPrank();

        uint256 spaceRatsBalanceAfterMint = address(spaceRats).balance;
        uint256 rickBalanceAfterMint = rick.balance;

        startHoax(rick, rick);
        spaceRats.withdrawFunds();
        vm.stopPrank();

        uint256 spaceRatsBalanceAfterWithdraw = address(spaceRats).balance;
        uint256 rickBalanceAfterWithdraw = rick.balance;

        assertEq(
            spaceRatsBalanceAfterMint - spaceRatsBalanceBeforeMint,
            AMOUNT_FOR_WHITELIST *
                WHITELIST_PRICE +
                NUMBER_MINTED *
                PUBLIC_PRICE
        );

        assertEq(spaceRatsBalanceAfterWithdraw, spaceRatsBalanceBeforeMint);

        assertEq(stdMath.delta(rickBalanceBeforeMint, rickBalanceAfterMint), 0);

        assertEq(
            rickBalanceAfterWithdraw - rickBalanceBeforeMint,
            AMOUNT_FOR_WHITELIST *
                WHITELIST_PRICE +
                NUMBER_MINTED *
                PUBLIC_PRICE
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper functions
    /// -----------------------------------------------------------------------

    function createWhitelistedUsers(uint256 userNum, uint256 mintNum)
        public
        returns (address[] memory users, uint256[] memory numSlots)
    {
        users = new address[](userNum);
        numSlots = new uint256[](userNum);

        for (uint256 i = 0; i < userNum; ++i) {
            address user = makeAddr("User");
            users[i] = user;
            numSlots[i] = mintNum;
        }
    }

    /**
    
    To do list:
        - Test SpaceRats__ReachedMaxSupply()
        - Helper function to generate 200 address with 200 slots of 5. (done)
    */
}
