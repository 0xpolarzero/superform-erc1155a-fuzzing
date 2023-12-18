// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { Invariants_Base } from "test/fuzzing/Invariants_Base.sol";
import { ERC1155A_Handler_Loose } from "test/fuzzing/ERC1155A_Loose/ERC1155A_Handler_Loose.t.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";

/// @dev forge test --match-contract ERC1155A_Invariants_Loose

contract ERC1155A_Invariants_Loose is Invariants_Base {
    function setUp() external {
        MockERC1155A mockERC1155A = new MockERC1155A();
        ERC1155A_Handler_Loose handler = new ERC1155A_Handler_Loose(mockERC1155A);
        init(address(handler), address(mockERC1155A));
    }
}
