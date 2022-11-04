// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721A/ERC721A.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract SpaceRats is Ownable, ERC721A, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    struct SaleConfig {
        uint32 publicSaleStartTime;
        uint64 whitelistPrice;
        uint64 publicPrice;
        uint32 publicSaleKey;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error SpaceRats__LargerCollectionSizeNeeded();
    error SpaceRats__PublicMintHasNotBegun();
    error SpaceRats__WhitelistMintHasNotBegun();
    error SpaceRats__IncorrectPublicSaleKey();
    error SpaceRats__CannotMintThisMany();
    error SpaceRats__ReachedMaxSupply();
    error SpaceRats__SendMoreEth();
    error SpaceRats__NotEligibleForWhitelistMint();
    error SpaceRats__ArrayLengthsDoNotMatch();
    error SpaceRats__TransferFailed();

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    uint256 public immutable maxPerAddressDuringMint;
    uint256 public immutable amountForWhitelist;
    uint256 public immutable amountForPublicAndWhitelist;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    mapping(address => uint256) public allowlist;

    SaleConfig public saleConfig;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 amountForPublicAndWhitelist_,
        uint256 amountForWhitelist_
    ) ERC721A("Space Rats", "SPACERATS", maxBatchSize_, collectionSize_) {
        maxPerAddressDuringMint = maxBatchSize_;
        amountForPublicAndWhitelist = amountForPublicAndWhitelist_;
        amountForWhitelist = amountForWhitelist_;
        if (amountForPublicAndWhitelist_ > collectionSize_)
            revert SpaceRats__LargerCollectionSizeNeeded();
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender);
        _;
    }

    /// -----------------------------------------------------------------------
    /// User actions: mint
    /// -----------------------------------------------------------------------

    function publicSaleMint(uint256 quantity, uint256 callerPublicSaleKey)
        external
        payable
        callerIsUser
    {
        SaleConfig memory config = saleConfig;
        uint256 publicSaleKey = uint256(config.publicSaleKey);
        uint256 publicPrice = uint256(config.publicPrice);
        uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);

        if (publicSaleKey != callerPublicSaleKey)
            revert SpaceRats__IncorrectPublicSaleKey();

        if (!isPublicSaleOn(publicPrice, publicSaleKey, publicSaleStartTime))
            revert SpaceRats__PublicMintHasNotBegun();

        if (totalSupply() + quantity > collectionSize)
            revert SpaceRats__ReachedMaxSupply();

        if (numberMinted(msg.sender) + quantity > maxPerAddressDuringMint)
            revert SpaceRats__CannotMintThisMany();

        _safeMint(msg.sender, quantity);
        refundIfOver(publicPrice * quantity);
    }

    function whitelistMint() external payable callerIsUser {
        uint256 price = uint256(saleConfig.whitelistPrice);
        if (price == 0) revert SpaceRats__WhitelistMintHasNotBegun();
        if (allowlist[msg.sender] == 0)
            revert SpaceRats__NotEligibleForWhitelistMint();
        if (totalSupply() + 1 > collectionSize)
            revert SpaceRats__ReachedMaxSupply();

        allowlist[msg.sender]--;
        _safeMint(msg.sender, 1);
        refundIfOver(price);
    }

    /// -----------------------------------------------------------------------
    /// Owner actions
    /// -----------------------------------------------------------------------

    function setupSaleInfo(
        uint32 publicSaleStartTime,
        uint64 whitelistPrice,
        uint64 publicPrice,
        uint32 publicSaleKey
    ) external onlyOwner {
        saleConfig = SaleConfig({
            publicSaleStartTime: publicSaleStartTime,
            whitelistPrice: whitelistPrice,
            publicPrice: publicPrice,
            publicSaleKey: publicSaleKey
        });
    }

    function setPublicSaleKey(uint32 key) external onlyOwner {
        saleConfig.publicSaleKey = key;
    }

    function seedWhitelist(
        address[] memory addresses,
        uint256[] memory numSlots
    ) external onlyOwner {
        if (addresses.length != numSlots.length)
            revert SpaceRats__ArrayLengthsDoNotMatch();

        for (uint256 i; i < addresses.length; ++i) {
            allowlist[addresses[i]] = numSlots[i];
        }
    }

    function addToWhitelist(address addr, uint256 numSlots) external onlyOwner {
        allowlist[addr] = numSlots;
    }

    function refundIfOver(uint256 price) private {
        if (msg.value < price) revert SpaceRats__SendMoreEth();

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert SpaceRats__TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// View functions
    /// -----------------------------------------------------------------------

    function isPublicSaleOn(
        uint256 publicPriceWei,
        uint256 publicSaleKey,
        uint256 publicSaleStartTime
    ) public view returns (bool) {
        return
            publicPriceWei != 0 &&
            publicSaleKey != 0 &&
            block.timestamp >= publicSaleStartTime;
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId)
        external
        view
        returns (TokenOwnership memory)
    {
        return ownershipOf(tokenId);
    }
}
