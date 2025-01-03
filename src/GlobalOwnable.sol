// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract GlobalOwnable is Ownable2Step {
    constructor(address _owner) Ownable(_owner) { }
}
