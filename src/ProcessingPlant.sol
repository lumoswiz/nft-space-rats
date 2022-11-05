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

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error ProcessingPlant__AccountDoesNotOwnThatTokenId();
    error ProcessingPlant__ProcessRoundIsNotOver();
    error ProcessingPlant__PlantDoesNotCustodyAllTokenIds();
    error ProcessingPlant__RequestIdDoesNotExist();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    VRFCoordinatorV2Interface immutable COORDINATOR;
    LinkTokenInterface immutable LINKTOKEN;
    bytes32 immutable s_keyHash;
    uint64 immutable s_subscriptionId;
    uint32 immutable s_callbackGasLimit = 100000;
    uint16 immutable s_requestConfirmations = 3;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------
    IridiumToken public iridium;
    Geode public geode;

    uint256 public processRound;
    uint256 public lastFinishedProcessRound;

    /// @notice processRound => ProcessingInfo (startTime, endTime)
    mapping(uint256 => ProcessingInfo) public roundInfo;

    /// @notice processRound => tokenIds array
    mapping(uint256 => uint256[]) public roundTokenIds;

    /// @notice tokenId => owner address
    mapping(uint256 => address) public rewardsFor;

    /// @notice address => number exercisable whitelist spots
    mapping(address => uint256) public exercisableWhitelistSpots;

    /// @notice processRound => requestId
    mapping(uint256 => uint256) public roundRequestId;

    /// @notice requestId => RequestStatus
    mapping(uint256 => RequestStatus) public s_requests;

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
            lastFinishedProcessRound = processRound;
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

    // Consider using a MAX_BATCH_SIZE for `requestRandomness`
    // Then track the next index to run request for in that processRound_
    function requestRandomness(uint256 processRound_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256 requestId)
    {
        if (block.timestamp < roundInfo[processRound_].endTime)
            revert ProcessingPlant__ProcessRoundIsNotOver();

        uint256[] memory balances = geode.balanceOfBatchSingleAddress(
            address(this),
            roundTokenIds[processRound_]
        );

        for (uint256 i; i < balances.length; ++i) {
            if (balances[i] == 0)
                revert ProcessingPlant__PlantDoesNotCustodyAllTokenIds();
        }

        uint32 s_numWords = uint32(roundTokenIds[processRound_].length);

        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );

        roundRequestId[processRound_] = requestId;

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        if (!s_requests[requestId].exists)
            revert ProcessingPlant__RequestIdDoesNotExist();

        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;
    }

    // function crackGeodes(uint256 processRound_) external onlyRole(DEFAULT_ADMIN_ROLE) {}

    function updateIridiumImplementation(IridiumToken iridium_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        iridium = iridium_;
    }

    function updateGeodeImplementation(Geode geode_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        geode = geode_;
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
