// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IridiumToken} from "./IridiumToken.sol";
import {Geode} from "./Geode.sol";

import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {ERC1155Holder} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import {VRFConsumerBaseV2} from "chainlink/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {LinkTokenInterface} from "chainlink/interfaces/LinkTokenInterface.sol";

contract ProcessingPlant is
    AccessControl,
    ReentrancyGuard,
    ERC1155Holder,
    VRFConsumerBaseV2
{
    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    struct ProcessGeode {
        address owner;
        uint256 tokenId;
    }

    struct ProcessingInfo {
        uint256 startTime;
        uint256 endTime;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ProcessingPlant__AccountDoesNotOwnThatTokenId();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    VRFCoordinatorV2Interface immutable COORDINATOR;
    LinkTokenInterface immutable LINKTOKEN;
    bytes32 immutable s_keyHash;
    uint64 immutable s_subscriptionId;
    uint32 immutable s_callbackGasLimit = 100000;
    uint16 immutable s_requestConfirmations = 3;
    uint32 public immutable s_numWords = 1;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------
    IridiumToken public iridium;
    Geode public geode;

    uint256 public processRound;

    /// @notice processRound => ProcessingInfo (startTime, endTime)
    mapping(uint256 => ProcessingInfo) public roundInfo;

    /// @notice processRound => tokenIds array
    mapping(uint256 => uint256[]) public roundTokenIds;

    /// @notice tokenId => owner address
    mapping(uint256 => address) public rewardsFor;

    /// @notice address => number exercisable whitelist spots
    mapping(address => uint256) public exercisableWhitelistSpots;

    /// @notice requestId => CrackGeode
    mapping(uint256 => ProcessGeode) public requestIdToSender;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        IridiumToken iridium_,
        Geode geode_,
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        iridium = iridium_;
        geode = geode_;

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    function processGeode(uint256 tokenId) external nonReentrant {
        if (geode.balanceOf(msg.sender, tokenId) == 0)
            revert ProcessingPlant__AccountDoesNotOwnThatTokenId();

        // Begin new processing round if the last one is over
        if (block.timestamp > roundInfo[processRound].endTime) {
            processRound++;
            roundInfo[processRound] = ProcessingInfo({
                startTime: block.timestamp,
                endTime: block.timestamp + 3 days
            });
        }

        geode.safeTransferFrom(msg.sender, address(this), tokenId, 1, "");

        roundTokenIds[processRound].push(tokenId);
        rewardsFor[tokenId] = msg.sender;
    }

    function requestRandomness() external onlyRole(DEFAULT_ADMIN_ROLE) {}

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {}

    function updateIridiumImplementation(IridiumToken iridium_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        iridium = iridium_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
