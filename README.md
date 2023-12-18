- Test with simple fuzzing and mirrors (call function with random inputs, update mirrors, compare mirrors with contract state in invariant)
- Test with more elaborate fuzzing (same but control inputs to discard invalid ones and update mirrors with conditions, to reflect how it is expected to behave)
- Test against OZ ERC1155 (do ERC1155-A batch operations in a loop, and compare both contracts states)

Take the following as an example to highlight the differences between tests.

ERC1155A_Handler_Loose

```solidity
function setApprovalForAll(uint256 senderSeed, uint256 operatorSeed, bool approved) public {
    // Grab either existing users (30% chance) or create new ones (70% chance)
    // Whenever a new one is created, they are added to the list and minted some tokens
    // Whenever some tokens are minted, it either grabs an existing id (30% chance) or creates a new one (70% chance)
    (address sender, address operator) = mockERC1155A_prepare_setApprovalForAll(senderSeed, operatorSeed);

    // Make the call
    vm.prank(sender);
    mockERC1155A.setApprovalForAll(operator, approved);

    // Update the mirrors, which are constantly compared with the contract state
    _updateApprovalForAllMirror(msg.sender, operator, approved);
}
```

# Overview

ERC1155A is an extension of ERC-1155 with extended approval and transmute logic, used in SuperPositions. This allows token owners to execute single id or multiple id approvals in place of mass approving all of the ERC1155 ids to the spender and to transmute ERC1155 ids to and from registered ERC20's.

Read more about ERC1155 here: https://docs.superform.xyz/periphery-contracts/superpositions/erc1155a

## Rationale

ERC1155 `setApprovalForAll` function gives full spending permissions over all currently exisiting and future Ids. Addition a of single Id approve allows this token standard to improve composability through more better allowance control of funds. If external contract is an expected to spend only a single ERC1155 id there is no reason it should have access to all the user owned ids.

ERC1155s additionally do not provide large composability with the DeFi ecosystem, so we provide the ability to transmute individual token ids via `transmuteToaERC20` to an ERC20 token. This may be reversed via `transmuteToERC1155A`.

## Implementation Details

The main change in approval logic is how ERC1155A implements the `safeTransferFrom()` function. Standard ERC1155 implementations only check if the caller in `isApprovedForAll` is an owner of token ids. We propose `setApprovalForOne()` or `setApprovalForMany()` function allowing approvals for specific id in any amount. Therefore, id owner is no longer required to mass approve all of his token ids. The side effect of it is requirement of additional validation logic inside of `safeTransferFrom()` function.

With gas effiency in mind and preservation of expected ERC1155 behavior, ERC1155A still prioritizes `isApprovedForAll` over `setApprovalForOne()`. Only `safeTransferFrom()` function works with single allowances, `safeBatchTransferFrom()` function requires owner to grant `setApprovalForAll()` to the operator. Decision is dictated by a significant gas costs overhead when required to decrease (or reset, in case of an overflow) allowances for each id in array. Moreover, if owner has `setApprovalForAll()` set to `true`, ERC1155A contract will not modify existing single allowances during `safeTransferFrom()` and `safeBatchTransferFrom()` - assuming that owner has full trust in _operator_ for granting mass approve. Therefore, ERC1155A requires owners to manage their allowances individually and be mindful of enabling `setApprovalForAll()` for external contracts.

ERC1155A token ids may also be transmuted into ERC20's, and transmuted back from the ERC20 through `transmute` functions after `registeraERC20` has been called to create the ERC20 token representation on the chain.

### Testing

You need foundry/forge to run repository.

`forge install`

`forge test`

Two set of tests are run. `ERC1155A` specific and general `ERC1155` tests forked from solmate's implementation of the standard. SuperForm's `ERC1155A` has exactly the same interface as standard `ERC1155` and expected behavior of functions follow EIP documentation.
