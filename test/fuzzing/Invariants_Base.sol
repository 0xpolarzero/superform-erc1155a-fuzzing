// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev These base invariants are run for each type of fuzzing campaign
/// (Loose, Strict, Discriminate).

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { Handler_Base } from "test/fuzzing/Handler_Base.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";
import { IaERC20 } from "src/interfaces/IaERC20.sol";

abstract contract Invariants_Base is StdInvariant, Test {
    MockERC1155A mockERC1155A;
    Handler_Base handler;

    function init(address _handler, address _mockERC1155A) internal {
        handler = Handler_Base(_handler);
        mockERC1155A = MockERC1155A(_mockERC1155A);
        targetContract(_handler);
    }

    /// @dev The total supply should be equal to the sum of all balances
    /// @dev The mirrored total supply should be equal to the total supply in the contract
    /// @dev The mirrored balances should be equal to the balances in the contract
    /// (both help verify the correctness of the execution flow)
    /// Note: Verifies the ERC1155-A logic, transfer and approval of ERC1155A tokens
    function invariant_ERC1155A_balancesAndTotalSupplyCorrectlyTracked() public {
        address[] memory users = handler.users();
        uint256[] memory tokenIds = handler.tokenIds();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 totalSupply = handler.mirror_totalSupply(tokenIds[i]);
            uint256 sumOfBalances = 0;

            for (uint256 j = 0; j < users.length; j++) {
                sumOfBalances += handler.mirror_balanceOf(users[j], tokenIds[i]);

                assertEq(
                    mockERC1155A.balanceOf(users[j], tokenIds[i]),
                    handler.mirror_balanceOf(users[j], tokenIds[i]),
                    "balanceOf != mirror_balanceOf"
                );
            }

            assertEq(totalSupply, sumOfBalances, "totalSupply != sumOfBalances");
            assertEq(mockERC1155A.totalSupply(tokenIds[i]), totalSupply, "totalSupply != mockERC1155A.totalSupply");
        }
    }

    /// @dev The mirrored balances in aERC20 tokens should be equal to the balances in each aERC20 token contract
    /// @dev The mirrored aERC20 tokens should be equal to the aERC20 token addresses in the contract
    /// Note: Verifies the transmutation logic, minting/burning of both ERC1155A and aERC20 tokens
    /// and registering of aERC20 tokens in the contract (should be done only once for each id)
    function invariant_aERC20_balancesCorrectlyTracked() public {
        address[] memory users = handler.users();
        uint256[] memory aERC20TokenIds = handler.aERC20TokenIds();

        for (uint256 i = 0; i < aERC20TokenIds.length; i++) {
            address token = handler.mirror_aERC20Tokens(aERC20TokenIds[i]);
            for (uint256 j = 0; j < users.length; j++) {
                assertEq(
                    IaERC20(token).balanceOf(users[j]),
                    handler.mirror_aERC20_balanceOf(users[j], aERC20TokenIds[i]),
                    "aERC20 balanceOf != mirror_aERC20_balanceOf"
                );
            }

            assertEq(
                mockERC1155A.aErc20TokenId(aERC20TokenIds[i]),
                handler.mirror_aERC20Tokens(aERC20TokenIds[i]),
                "aERC20 tokenId address != mirror_aERC20Tokens"
            );
        }
    }
}
