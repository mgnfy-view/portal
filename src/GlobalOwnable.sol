// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title GlobalOwnable.
/// @author mgnfy-view.
/// @notice This contract owns the `AssetRegistry`, `PythOracle`, and `SourcePortal`
/// contracts.
contract GlobalOwnable is Ownable2Step {
    /// @notice Sets the initial global owner.
    /// @param _owner The initial global owner address.
    constructor(address _owner) Ownable(_owner) { }
}
