// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev Here we compare the flow of the contract to mirrors, with a more assertive approach than in the loose handler;
/// then we compare these mirrors to the state of the contract, both in invariants and after each call.
/// @dev Basically, the flaw is:
/// - get semi-random inputs (same as in the loose handler);
/// - call the function in the contract with theses inputs;
/// - if the call is successful, verify that the right conditions were met;
/// - if the call is unsuccessful, verify that the contract is updated correctly;
/// - update the mirrors

/// @dev This is comparable to the 'imply'/`=>` strategy, where whenever the tracker ERC1155 contract is updated, it
/// implies that the right conditions were met. Testing the contract's state both after each call AND in invariants
/// might be a bit overkill, but anyway.

import { Test } from "forge-std/Test.sol";

import { Handler_Base } from "test/fuzzing/Handler_Base.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";
import { IaERC20 } from "src/interfaces/IaERC20.sol";

contract ERC1155A_Handler_Strict is Handler_Base {
    constructor(MockERC1155A _mockERC1155A) Handler_Base(_mockERC1155A) { }

    /* ----------------------------- ERC1155-A LOGIC ---------------------------- */

    function safeTransferFrom(
        uint256 senderSeed,
        uint256 fromSeed,
        uint256 toSeed,
        uint256 idSeed,
        uint256 amount,
        bytes memory data
    )
        public
    {
        (address sender, address from, address to, uint256 id) =
            mockERC1155A_prepare_safeTransferFrom(senderSeed, fromSeed, toSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.safeTransferFrom(from, to, id, amount, data);

        /// Check pre-conditions
        // If the caller is not the owner, allowance should have been >= amount or approved for all
        assert(
            implies(
                sender != from, mirror_allowances[from][sender][id] >= amount || mirror_isApprovedForAll[from][sender]
            )
        );
        // The sender should have had enough balance
        assert(mirror_balanceOf[from][id] >= amount);

        /// Check state changes
        // If the caller is not owner and it's not approved for all, allowance should be decreased
        if (sender != from && !mirror_isApprovedForAll[from][sender]) {
            mockERC1155A.allowance(from, sender, id) == mirror_allowances[from][sender][id] - amount;
        }
        // Receiver should be transferred the amount
        assert(
            from == to
                ? mockERC1155A.balanceOf(to, id) == mirror_balanceOf[to][id]
                : mockERC1155A.balanceOf(to, id) == mirror_balanceOf[to][id] + amount
        );

        /// Update mirrors
        _updateSingleBalancesMirror(from, to, id, amount, false);
    }

    /* ------------------------------ ERC1155 LOGIC ----------------------------- */

    function setApprovalForAll(uint256 senderSeed, uint256 operatorSeed, bool approved) public {
        (address sender, address operator) = mockERC1155A_prepare_setApprovalForAll(senderSeed, operatorSeed);

        vm.prank(sender);
        mockERC1155A.setApprovalForAll(operator, approved);

        /// Check state changes
        assert(mockERC1155A.isApprovedForAll(sender, operator) == approved);

        /// Update mirrors
        _updateApprovalForAllMirror(sender, operator, approved);
    }

    function safeBatchTransferFrom(
        uint256 senderSeed,
        uint256 fromSeed,
        uint256 toSeed,
        uint256[] memory idSeeds,
        uint256[] memory amounts,
        bytes memory data
    )
        public
    {
        (address sender, address from, address to, uint256[] memory ids) =
            mockERC1155A_prepare_safeBatchTransferFrom(senderSeed, fromSeed, toSeed, idSeeds);

        vm.prank(sender);
        mockERC1155A.safeBatchTransferFrom(from, to, ids, amounts, data);

        /// Check pre-conditions
        // Lengths should have matched
        assert(ids.length == amounts.length);

        // Was the sender the owner, or was it approved for all?
        bool singleApproval = sender != from && !mirror_isApprovedForAll[from][sender];
        for (uint256 i; i < ids.length; i++) {
            // If the caller was not the owner and it was not approved for all, allowance should have been >= amount
            assert_implies(singleApproval, mirror_allowances[from][sender][ids[i]] >= amounts[i]);
            // The sender should have had enough balance
            assert(mirror_balanceOf[from][ids[i]] >= amounts[i]);
        }

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // If the caller is not owner and it's not approved for all, allowance should be decreased
            if (singleApproval) {
                mockERC1155A.allowance(from, sender, ids[i]) == mirror_allowances[from][sender][ids[i]] - amounts[i];
            }
            // Receiver should be transferred the amount
            assert(
                from == to
                    ? mockERC1155A.balanceOf(to, ids[i]) == mirror_balanceOf[to][ids[i]]
                    : mockERC1155A.balanceOf(to, ids[i]) == mirror_balanceOf[to][ids[i]] + amounts[i]
            );
        }

        /// Update mirrors
        _updateMultiBalancesMirror(from, to, ids, amounts);
    }

    /* ----------------------------- SINGLE APPROVE ----------------------------- */

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

    function increaseAllowance(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 addedValue) public {
        (address sender, address spender, uint256 id) =
            mockERC1155A_prepare_increaseAllowance(senderSeed, spenderSeed, idSeed);

        vm.prank(sender);
        bool success = mockERC1155A.increaseAllowance(spender, id, addedValue);
        assert(success);

        /// Check pre-conditions
        assert(sender != address(0) && spender != address(0));

        /// Check state changes
        assert(mockERC1155A.allowance(sender, spender, id) == mirror_allowances[sender][spender][id] + addedValue);

        /// Update mirrors
        _updateSingleAllowanceMirror(sender, spender, id, mirror_allowances[sender][spender][id] + addedValue);
    }

    function decreaseAllowance(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256 idSeed,
        uint256 subtractedValue
    )
        public
    {
        (address sender, address spender, uint256 id) =
            mockERC1155A_prepare_decreaseAllowance(senderSeed, spenderSeed, idSeed);

        vm.prank(sender);
        bool success = mockERC1155A.decreaseAllowance(spender, id, subtractedValue);
        assert(success);

        /// Check pre-conditions
        assert(sender != address(0) && spender != address(0));
        // Allowance should have been enough
        assert(mirror_allowances[sender][spender][id] >= subtractedValue);

        /// Check state changes
        assert(mockERC1155A.allowance(sender, spender, id) == mirror_allowances[sender][spender][id] - subtractedValue);

        /// Update mirrors
        _updateSingleAllowanceMirror(sender, spender, id, mirror_allowances[sender][spender][id] - subtractedValue);
    }

    /* ------------------------------ MULTI APPROVE ----------------------------- */

    function setApprovalForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds,
        uint256[] memory amounts
    )
        public
    {
        (address sender, address spender, uint256[] memory ids) =
            mockERC1155A_prepare_setApprovalForMany(senderSeed, spenderSeed, idSeeds);

        vm.prank(sender);
        mockERC1155A.setApprovalForMany(spender, ids, amounts);

        /// Check pre-conditions
        assert(sender != address(0) && spender != address(0));
        assert(ids.length == amounts.length); // not done explicitly in the contract but would revert if not

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            assert(mockERC1155A.allowance(sender, spender, ids[i]) == amounts[i]);
        }

        /// Update mirrors
        _setMultiAllowancesMirror(sender, spender, ids, amounts);
    }

    function increaseAllowanceForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds,
        uint256[] memory addedValues
    )
        public
    {
        (address sender, address spender, uint256[] memory ids) =
            mockERC1155A_prepare_increaseAllowanceForMany(senderSeed, spenderSeed, idSeeds);

        vm.prank(sender);
        bool success = mockERC1155A.increaseAllowanceForMany(spender, ids, addedValues);
        assert(success);

        /// Check pre-conditions
        assert(sender != address(0) && spender != address(0));
        assert(ids.length == addedValues.length); // not done explicitly but would revert if not

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // Allowance should be increased
            assert(
                mockERC1155A.allowance(sender, spender, ids[i])
                    == mirror_allowances[sender][spender][ids[i]] + addedValues[i]
            );
        }

        /// Update mirrors
        _increaseMultiAllowancesMirror(sender, spender, ids, addedValues);
    }

    function decreaseAllowanceForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds,
        uint256[] memory subtractedValues
    )
        public
    {
        (address sender, address spender, uint256[] memory ids) =
            mockERC1155A_prepare_decreaseAllowanceForMany(senderSeed, spenderSeed, idSeeds);

        vm.prank(sender);
        bool success = mockERC1155A.decreaseAllowanceForMany(spender, ids, subtractedValues);
        assert(success);

        /// Check pre-conditions
        assert(sender != address(0) && spender != address(0));
        assert(ids.length == subtractedValues.length); // not done explicitly but would revert if not

        for (uint256 i; i < ids.length; i++) {
            assert(mirror_allowances[sender][spender][ids[i]] >= subtractedValues[i]);
        }

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            assert(
                mockERC1155A.allowance(sender, spender, ids[i])
                    == mirror_allowances[sender][spender][ids[i]] - subtractedValues[i]
            );
        }

        /// Update mirrors
        _decreaseMultiAllowancesMirror(sender, spender, ids, subtractedValues);
    }

    /* --------------------------- AERC20 & TRANSMUTE --------------------------- */

    function registerAERC20(uint256 idSeed) public {
        uint256 id = mockERC1155A_prepare_registerAERC20(idSeed);

        address token = mockERC1155A.registerAERC20(id);

        /// Check pre-conditions
        // The token should not have been registered yet
        assert(mirror_aERC20Tokens[id] == address(0));
        // There should have been at least one unit circulating for this id
        assert(mirror_totalSupply[id] > 0);

        /// Check state changes
        // (Mock) It should be registered
        assert(token != address(0));
        assert(mockERC1155A.aErc20TokenId(id) == token);

        /// Update mirrors
        _setAERC20TokenIdMirror(id, token);
    }

    function transmuteBatchToERC20(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256[] memory idSeeds,
        uint256[] memory amounts
    )
        public
    {
        (address sender, address owner, uint256[] memory ids) =
            mockERC1155A_prepare_transmuteBatchToERC20(senderSeed, ownerSeed, idSeeds);

        vm.prank(sender);
        mockERC1155A.transmuteBatchToERC20(owner, ids, amounts);

        /// Check pre-conditions
        assert(ids.length == amounts.length);
        assert(owner != address(0)); // condition in aERC20 `mint()`
        bool singleApproval = sender != owner && !mirror_isApprovedForAll[owner][sender];

        for (uint256 i; i < ids.length; i++) {
            // If the caller was not the owner and it was not approved for all, allowance should have been >= amount
            assert_implies(singleApproval, mirror_allowances[owner][sender][ids[i]] >= amounts[i]);
            // The sender should have had enough balance
            assert(mirror_balanceOf[owner][ids[i]] >= amounts[i]);
            // If the token was not registered yet, it should have failed
            assert(mirror_aERC20Tokens[ids[i]] != address(0));
        }

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // If the caller is not owner and it's not approved for all, allowance should be decreased
            if (singleApproval) {
                mockERC1155A.allowance(owner, sender, ids[i]) == mirror_allowances[owner][sender][ids[i]] - amounts[i];
            }
            // Balance should have been decreased
            assert(mockERC1155A.balanceOf(owner, ids[i]) == mirror_balanceOf[owner][ids[i]] - amounts[i]);
            // Total supply should be decreased
            assert(mockERC1155A.totalSupply(ids[i]) == mirror_totalSupply[ids[i]] - amounts[i]);
            // Balance (aERC20) should be increased
            assert(
                IaERC20(mirror_aERC20Tokens[ids[i]]).balanceOf(owner)
                    == mirror_aERC20_balanceOf[owner][ids[i]] + amounts[i]
            );
        }

        /// Update mirrors
        _updateMultiTransmutedToERC20Mirror(owner, ids, amounts);
    }

    function transmuteBatchToERC1155A(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256[] memory idSeeds,
        uint256[] memory amounts
    )
        public
    {
        (address sender, address owner, uint256[] memory ids) =
            mockERC1155A_prepare_transmuteBatchToERC1155A(senderSeed, ownerSeed, idSeeds);

        vm.prank(sender);
        mockERC1155A.transmuteBatchToERC1155A(owner, ids, amounts);

        /// Check pre-conditions
        assert(ids.length == amounts.length); // not done explicitly in the contract but would revert if not
        assert(owner != address(0)); // condition in aERC20 `burn()`

        for (uint256 i; i < ids.length; i++) {
            // The sender should have had enough balance
            assert(mirror_aERC20_balanceOf[owner][ids[i]] >= amounts[i]);
            // If the token was not registered yet, it should have failed
            assert(mirror_aERC20Tokens[ids[i]] != address(0));
        }

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // Balance (ERC1155-A) should be increased
            assert(mockERC1155A.balanceOf(owner, ids[i]) == mirror_balanceOf[owner][ids[i]] + amounts[i]);
            // Total supply should be increased
            assert(mockERC1155A.totalSupply(ids[i]) == mirror_totalSupply[ids[i]] + amounts[i]);
            // Balance (aERC20) should be decreased
            assert(
                IaERC20(mirror_aERC20Tokens[ids[i]]).balanceOf(owner)
                    == mirror_aERC20_balanceOf[owner][ids[i]] - amounts[i]
            );
        }

        /// Update mirrors
        _updateMultiTransmutedToERC1155AMirror(owner, ids, amounts);
    }

    function transmuteToERC20(uint256 senderSeed, uint256 ownerSeed, uint256 idSeed, uint256 amount) public {
        (address sender, address owner, uint256 id) =
            mockERC1155A_prepare_transmuteToERC20(senderSeed, ownerSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.transmuteToERC20(owner, id, amount);

        /// Check pre-conditions
        assert(owner != address(0)); // condition in aERC20 `mint()`
        bool singleApproval = sender != owner && !mirror_isApprovedForAll[owner][sender];

        // If the caller was not the owner and it was not approved for all, allowance should have been >= amount
        assert_implies(singleApproval, mirror_allowances[owner][sender][id] >= amount);
        // The sender should have had enough balance
        assert(mirror_balanceOf[owner][id] >= amount);
        // If the token was not registered yet, it should have failed
        assert(mirror_aERC20Tokens[id] != address(0));

        /// Check state changes
        // If the caller is not owner and it's not approved for all, allowance should be decreased
        if (singleApproval) mockERC1155A.allowance(owner, sender, id) == mirror_allowances[owner][sender][id] - amount;
        // Balance should have been decreased
        assert(mockERC1155A.balanceOf(owner, id) == mirror_balanceOf[owner][id] - amount);
        // Total supply should be decreased
        assert(mockERC1155A.totalSupply(id) == mirror_totalSupply[id] - amount);
        // Balance (aERC20) should be increased
        assert(IaERC20(mirror_aERC20Tokens[id]).balanceOf(owner) == mirror_aERC20_balanceOf[owner][id] + amount);

        /// Update mirrors
        _updateSingleTransmutedToERC20Mirror(owner, id, amount);
    }

    function transmuteToERC1155A(uint256 senderSeed, uint256 ownerSeed, uint256 idSeed, uint256 amount) public {
        (address sender, address owner, uint256 id) =
            mockERC1155A_prepare_transmuteToERC1155A(senderSeed, ownerSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.transmuteToERC1155A(owner, id, amount);

        /// Check pre-conditions
        assert(owner != address(0)); // condition in aERC20 `burn()`
        // The sender should have had enough balance
        assert(mirror_aERC20_balanceOf[owner][id] >= amount);
        // If the token was not registered yet, it should have failed
        assert(mirror_aERC20Tokens[id] != address(0));

        /// Check state changes
        // Balance (ERC1155-A) should be increased
        assert(mockERC1155A.balanceOf(owner, id) == mirror_balanceOf[owner][id] + amount);
        // Total supply should be increased
        assert(mockERC1155A.totalSupply(id) == mirror_totalSupply[id] + amount);
        // Balance (aERC20) should be decreased
        assert(IaERC20(mirror_aERC20Tokens[id]).balanceOf(owner) == mirror_aERC20_balanceOf[owner][id] - amount);

        /// Update mirrors
        _updateSingleTransmutedToERC1155AMirror(owner, id, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   HELPERS                                  */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------- BALANCES -------------------------------- */

    function _updateSingleBalancesMirror(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bool totalSupply
    )
        internal
        override
    {
        if (from != address(0)) {
            mirror_balanceOf[from][id] -= amount;
        }
        if (to != address(0)) {
            mirror_balanceOf[to][id] += amount;
        }

        if (totalSupply) {
            mirror_totalSupply[id] += amount;
        }
    }

    function _updateMultiBalancesMirror(
        address from,
        address to,
        uint256[] memory id,
        uint256[] memory amounts
    )
        internal
        override
    {
        for (uint256 i = 0; i < id.length; i++) {
            if (from != address(0)) {
                mirror_balanceOf[from][id[i]] -= amounts[i];
            }
            if (to != address(0)) {
                mirror_balanceOf[to][id[i]] += amounts[i];
            }
        }
    }

    /* ------------------------------- ALLOWANCES ------------------------------- */

    function _updateSingleAllowanceMirror(
        address owner,
        address spender,
        uint256 id,
        uint256 amount
    )
        internal
        override
    {
        mirror_allowances[owner][spender][id] = amount;
    }

    function _setMultiAllowancesMirror(
        address owner,
        address spender,
        uint256[] memory id,
        uint256[] memory amounts
    )
        internal
        override
    {
        for (uint256 i = 0; i < id.length; i++) {
            mirror_allowances[owner][spender][id[i]] = amounts[i];
        }
    }

    function _increaseMultiAllowancesMirror(
        address owner,
        address spender,
        uint256[] memory id,
        uint256[] memory addedValues
    )
        internal
        override
    {
        for (uint256 i = 0; i < id.length; i++) {
            mirror_allowances[owner][spender][id[i]] += addedValues[i];
        }
    }

    function _decreaseMultiAllowancesMirror(
        address owner,
        address spender,
        uint256[] memory id,
        uint256[] memory subtractedValues
    )
        internal
        override
    {
        for (uint256 i = 0; i < id.length; i++) {
            mirror_allowances[owner][spender][id[i]] -= subtractedValues[i];
        }
    }

    function _updateApprovalForAllMirror(address owner, address spender, bool approved) internal override {
        mirror_isApprovedForAll[owner][spender] = approved;
    }

    /* ------------------------------ TRANSMUTATION ----------------------------- */

    function _setAERC20TokenIdMirror(uint256 id, address aToken) internal override {
        mirror_aERC20Tokens[id] = aToken;
        _aERC20TokenIds.push(id);
    }

    function _updateSingleTransmutedToERC20Mirror(address owner, uint256 id, uint256 amount) internal override {
        mirror_balanceOf[owner][id] -= amount;
        mirror_totalSupply[id] -= amount;
        mirror_aERC20_balanceOf[owner][id] += amount;
    }

    function _updateMultiTransmutedToERC20Mirror(
        address owner,
        uint256[] memory ids,
        uint256[] memory amounts
    )
        internal
        override
    {
        for (uint256 i = 0; i < ids.length; i++) {
            mirror_balanceOf[owner][ids[i]] -= amounts[i];
            mirror_totalSupply[ids[i]] -= amounts[i];
            mirror_aERC20_balanceOf[owner][ids[i]] += amounts[i];
        }
    }

    function _updateSingleTransmutedToERC1155AMirror(address owner, uint256 id, uint256 amount) internal override {
        mirror_balanceOf[owner][id] += amount;
        mirror_totalSupply[id] += amount;
        mirror_aERC20_balanceOf[owner][id] -= amount;
    }

    function _updateMultiTransmutedToERC1155AMirror(
        address owner,
        uint256[] memory ids,
        uint256[] memory amounts
    )
        internal
        override
    {
        for (uint256 i = 0; i < ids.length; i++) {
            mirror_balanceOf[owner][ids[i]] += amounts[i];
            mirror_totalSupply[ids[i]] += amounts[i];
            mirror_aERC20_balanceOf[owner][ids[i]] -= amounts[i];
        }
    }
}
