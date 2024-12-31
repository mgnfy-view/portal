// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library Math {
    uint16 private constant BPS = 10_000;

    function applyPercentage(uint256 _value, uint16 _percentageInBPs) internal pure returns (uint256) {
        return (_value * _percentageInBPs) / BPS;
    }
}
