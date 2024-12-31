// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IGlobalOwnerChecker } from "../interfaces/IGlobalOwnerChecker.sol";
import { IOwnable } from "../interfaces/IOwnable.sol";

abstract contract GlobalOwnerChecker is IGlobalOwnerChecker {
    IOwnable internal immutable i_globalOwnable;

    modifier onlyGlobalOwner() {
        address globalOwner = i_globalOwnable.owner();
        if (msg.sender != globalOwner) revert GlobalOwnerChecker__NotOwner(msg.sender, globalOwner);

        _;
    }

    constructor(address _globalOwnable) {
        if (_globalOwnable == address(0)) revert GlobalOwnerChecker__AddressZero();

        i_globalOwnable = IOwnable(_globalOwnable);
    }

    function getGlobalOwnable() external view returns (address) {
        return address(i_globalOwnable);
    }

    function getGlobalOwner() external view returns (address) {
        return i_globalOwnable.owner();
    }
}
