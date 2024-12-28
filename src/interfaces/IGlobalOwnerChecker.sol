// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IGlobalOwnerChecker {
    error GlobalOwnableChecker__NotOwner(address caller, address globalOwner);
    error GlobalOwnerChecker__AddressZero();
}
