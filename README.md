# Superform ERC1155A fuzzing/invariants testing

ERC1155A is an extension of ERC-1155 with extended approval and transmute logic, used in Superform contracts for SuperPositions. This allows token owners to execute single id or multiple id approvals in place of mass approving all of the ERC1155 ids to the spender and to transmute ERC1155 ids to and from registered ERC20's.

[Read more about ERC1155 here](https://docs.superform.xyz/periphery-contracts/superpositions/erc1155a)

## Idea

These are the fuzzing tests I wrote for the ERC1155A contract. Basically, the rationale is pretty simple, as there are 3 kinds of tests, verifying the same invariants but embedded in different contexts.

For each handler, the invariants are being checked constantly, comparing the state of the contract with the mirrors.

```solidity
assertEq(
  mockERC1155A.balanceOf(users[j], tokenIds[i]),
  handler.mirror_balanceOf(users[j], tokenIds[i]),
  "balanceOf != mirror_balanceOf"
);

...

assertEq(totalSupply, sumOfBalances, "totalSupply != sumOfBalances");
assertEq(mockERC1155A.totalSupply(tokenIds[i]), totalSupply, "totalSupply != mockERC1155A.totalSupply");
```

There are 3 different handlers, each one with a different approach. These explanations are accompanied by a very basic example for the sake of conciseness, please check the code for more relevant examples.

1. [Loose Handler](./test/fuzzing/ERC1155A_Loose/ERC1155A_Handler_Loose.t.sol): Most assertions are performed against mirrors, but the functions are called with a mix a random and almost-random inputs. If any call is successful, the mirrors are updated accordingly. Using a very simple case:

```solidity
function setApprovalForOne(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 amount) public {
  (address sender, address spender, uint256 id) =
    mockERC1155A_prepare_setApprovalForOne(senderSeed, spenderSeed, idSeed);

  vm.prank(sender);
  mockERC1155A.setApprovalForOne(spender, id, amount);

   _updateSingleAllowanceMirror(msg.sender, spender, id, amount);
}
```

2. [Strict Handler](./test/fuzzing/ERC1155A_Strict/ERC1155A_Handler_Strict.t.sol): Same as the loose handler, but after each call, the state of the contract _prior to the call_ is verified, to make sure that the right conditions were indeed met for this call to succeed. Using the same example:

```solidity
function setApprovalForOne(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 amount) public {
  (address sender, address spender, uint256 id) =
    mockERC1155A_prepare_setApprovalForOne(senderSeed, spenderSeed, idSeed);

  vm.prank(sender);
  mockERC1155A.setApprovalForOne(spender, id, amount);

  /// Check pre-conditions
  assert(sender != address(0) && spender != address(0));

  /// Check state changes
  assert(mockERC1155A.allowance(sender, spender, id) == amount);

  /// Update mirrors
   _updateSingleAllowanceMirror(sender, spender, id, amount);
}
```

3. [Discriminate Handler](./test/fuzzing/ERC1155A_Strict_Mock/ERC1155A_Handler_Discriminate.t.sol): Same as the strict handler above, but additionally, any input that is not suitable for the call is either discarded or adapted, so it can result in more meaningful state changes. Using the same example:

```solidity
function setApprovalForOne(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 amount) public {
  (address sender, address spender, uint256 id) =
    mockERC1155A_prepare_setApprovalForOne(senderSeed, spenderSeed, idSeed);

  /// Discard inputs that don't meet pre-conditions
  if (sender == address(0) || spender == address(0)) return;

  vm.prank(sender);
  mockERC1155A.setApprovalForOne(spender, id, amount);

  /// Check state changes
  assert(mockERC1155A.allowance(sender, spender, id) == amount);

  /// Update mirrors
  _updateSingleAllowanceMirror(sender, spender, id, amount);
}
```

## Running tests

1. Clone this repo and install Foundry.

2. Update settings in [foundry.toml](./foundry.toml):

```toml
[invariant]
runs = 32 # Number of runs per test
depth = 128 # Number of calls per run
fail_on_revert = false # Stop the test on revert, or not
```

3. Run the tests:

```bash
# Run Loose tests
forge test --match-contract ERC1155A_Invariants_Loose

# Run Strict tests
forge test --match-contract ERC1155A_Invariants_Strict

# Run Discriminate tests
forge test --match-contract ERC1155A_Invariants_Discriminate
```
