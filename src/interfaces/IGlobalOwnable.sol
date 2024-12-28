// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IGlobalOwnable {
    error GlobalOwnable__AddressZero();

    function owner() external view returns (address);
}
