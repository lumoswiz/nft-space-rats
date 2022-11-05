// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IridiumToken} from "./IridiumToken.sol";

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

import {VRFConsumerBaseV2} from "chainlink/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import {LinkTokenInterface} from "chainlink/interfaces/LinkTokenInterface.sol";

contract Geode is ERC1155, ERC1155Burnable, ERC1155Supply, AccessControl {
    uint256 public tokenCounter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    // Add the staking contract address as input to constructor -> grantRole(address(stakingContract), MINTER_ROLE)
    constructor(string memory _uri) payable ERC1155(_uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /// -----------------------------------------------------------------------
    /// Role actions (MINTER, BURNER, DEFAULT_ADMIN_ROLE)
    /// -----------------------------------------------------------------------

    function mint(address account) external onlyRole(MINTER_ROLE) {
        _mint(account, tokenCounter, 1, "");
        tokenCounter++;
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override onlyRole(BURNER_ROLE) {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public override onlyRole(BURNER_ROLE) {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burnBatch(account, ids, values);
    }

    function balanceOfBatchSingleAddress(address account, uint256[] memory ids)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory batchBalances = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; ++i) {
            batchBalances[i] = balanceOf(account, ids[i]);
        }

        return batchBalances;
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
