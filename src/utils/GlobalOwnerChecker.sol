// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IGlobalOwnable } from "../interfaces/IGlobalOwnable.sol";
import { IGlobalOwnerChecker } from "../interfaces/IGlobalOwnerChecker.sol";

abstract contract GlobalOwnerChecker is IGlobalOwnerChecker {
    IGlobalOwnable internal immutable i_globalOwnable;

    modifier onlyGlobalOwner() {
        address globalOwner = i_globalOwnable.owner();
        if (msg.sender != globalOwner) revert GlobalOwnerChecker__NotOwner(msg.sender, globalOwner);

        _;
    }

    constructor(address _globalOwnable) {
        if (_globalOwnable == address(0)) revert GlobalOwnerChecker__AddressZero();

        i_globalOwnable = IGlobalOwnable(_globalOwnable);
    }

    function getGlobalOwnable() external view returns (address) {
        return address(i_globalOwnable);
    }
}
