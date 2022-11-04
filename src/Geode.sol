// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

contract Geode is ERC1155, ERC1155Burnable, ERC1155Supply, AccessControl {
    uint256 public _tokenIds;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // error Geode__ArrayLengthsDiffer();

    // Add the staking contract address as input to constructor -> grantRole(address(stakingContract), MINTER_ROLE)
    constructor(string memory _uri) payable ERC1155(_uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mint(address account) external onlyRole(MINTER_ROLE) {
        _mint(account, _tokenIds, 1, "");
        _tokenIds++;
    }

    // UNLIKELY TO MINT MULTIPLE AT A TIME? IF NOT, THEN DELETE THIS.
    //    function mintBatch(
    //        address to,
    //        uint256 idsLength,
    //        uint256[] memory amounts
    //    ) external onlyRole(MINTER_ROLE) {
    //        if (amounts.length != idsLength) revert Geode__ArrayLengthsDiffer();
    //
    //        uint256[] memory ids = new uint256[](idsLength);
    //
    //        for (uint256 i; i < idsLength; ++i) {
    //            ids[i] = _tokenIds + i;
    //        }
    //
    //        _mintBatch(to, ids, amounts, "");
    //
    //        _tokenIds = _tokenIds + idsLength - 1;
    //    }

    function setURI(string memory newuri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setURI(newuri);
    }

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
