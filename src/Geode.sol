// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

import {VRFConsumerBaseV2} from "chainlink/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {LinkTokenInterface} from "chainlink/interfaces/LinkTokenInterface.sol";

contract Geode is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    AccessControl,
    VRFConsumerBaseV2
{
    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    struct CrackGeode {
        address owner;
        uint256 tokenId;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event crackGeodeRequested(
        address indexed requester,
        uint256 indexed tokenId,
        uint256 indexed requestId
    );

    event geodeCracked();

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Geode__AccountDoesNotOwnThatTokenId();
    error Geode__TokenIdDoesNotExist();

    /// -----------------------------------------------------------------------
    /// Chainlink VRFConsumerBaseV2 variables
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

    /// @notice requestId => CrackGeode
    mapping(uint256 => CrackGeode) public requestIdToSender;

    uint256 public tokenCounter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    // Add the staking contract address as input to constructor -> grantRole(address(stakingContract), MINTER_ROLE)
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 keyHash,
        string memory _uri
    ) payable ERC1155(_uri) VRFConsumerBaseV2(vrfCoordinator) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    function crackGeode(uint256 tokenId) external returns (uint256 requestId) {
        if (tokenId > tokenCounter) revert Geode__TokenIdDoesNotExist();

        if (balanceOf(msg.sender, tokenId) == 0)
            revert Geode__AccountDoesNotOwnThatTokenId();

        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );

        requestIdToSender[requestId] = CrackGeode({
            owner: msg.sender,
            tokenId: tokenId
        });

        emit crackGeodeRequested(msg.sender, tokenId, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        uint256 s_randomWords = (randomWords[0] % 100) + 1;
    }

    /// -----------------------------------------------------------------------
    /// Role actions (MINTER, DEFAULT_ADMIN_ROLE)
    /// -----------------------------------------------------------------------

    function mint(address account) external onlyRole(MINTER_ROLE) {
        _mint(account, tokenCounter, 1, "");
        tokenCounter++;
    }

    function setURI(string memory newuri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setURI(newuri);
    }

    /// -----------------------------------------------------------------------
    /// Overrides
    /// -----------------------------------------------------------------------

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
