// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev forge test --match-contract ERC1155A_Invariants_Discriminate

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { Invariants_Base } from "test/fuzzing/Invariants_Base.sol";
import { ERC1155A_Handler_Discriminate } from "test/fuzzing/ERC1155A_Discriminate/ERC1155A_Handler_Discriminate.t.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";

contract ERC1155A_Invariants_Discriminate is Invariants_Base {
    function setUp() external {
        MockERC1155A mockERC1155A = new MockERC1155A();
        ERC1155A_Handler_Discriminate handler = new ERC1155A_Handler_Discriminate(mockERC1155A);
        init(address(handler), address(mockERC1155A));
    }
}
