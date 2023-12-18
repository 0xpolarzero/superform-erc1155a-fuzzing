// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev forge test --match-contract ERC1155A_Invariants_Strict

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { Invariants_Base } from "test/fuzzing/Invariants_Base.sol";
import { ERC1155A_Handler_Strict } from "test/fuzzing/ERC1155A_Strict/ERC1155A_Handler_Strict.t.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";

contract ERC1155A_Invariants_Strict is Invariants_Base {
    function setUp() external {
        MockERC1155A mockERC1155A = new MockERC1155A();
        ERC1155A_Handler_Strict handler = new ERC1155A_Handler_Strict(mockERC1155A);
        init(address(handler), address(mockERC1155A));
    }
}
