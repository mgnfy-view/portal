// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IGlobalOwnerChecker {
    error GlobalOwnerChecker__NotOwner(address caller, address globalOwner);
    error GlobalOwnerChecker__AddressZero();

    function getGlobalOwnable() external returns (address);

    function getGlobalOwner() external view returns (address);
}
