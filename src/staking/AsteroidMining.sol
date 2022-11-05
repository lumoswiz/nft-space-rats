// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.14;

import {Bagholder} from "bagholder/Bagholder.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

import "bagholder/lib/Structs.sol";

contract AsteroidMining is Bagholder {
    constructor(ProtocolFeeInfo memory protocolFeeInfo_)
        Bagholder(protocolFeeInfo_)
    {}
}
