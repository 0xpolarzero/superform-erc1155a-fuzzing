// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test, console } from "forge-std/Test.sol";

import { Handler_Base } from "test/fuzzing/Handler_Base.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";
import { IaERC20 } from "src/interfaces/IaERC20.sol";

/// @dev This is basically the same as the `ERC1155A_Handler_Strict` handler, but with more fine-grained control
/// over the inputs, to produce more successfull calls, and test the behavior in both a more in-depth and realistic way.
/// @dev Basically, the flaw is:
/// - discard/adapt random inputs to make them suitable for the call;
/// - call the function in the contract with theses inputs;
/// - if the call is successful, verify that the right conditions were met;
/// - if the call is unsuccessful, verify that the contract is updated correctly;
/// - update the mirrors
/// @dev Even more basically, it's the strict handler, but instead of verifying that pre-conditions were met, we
/// actually discard inputs that don't meet them.

contract ERC1155A_Handler_Discriminate is Handler_Base {
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

        /// Discard inputs that don't meet pre-conditions
        // If the caller is not the owner, allowance should be >= amount or approved for all
        if (
            !implies(
                sender != from, mirror_allowances[from][sender][id] >= amount || mirror_isApprovedForAll[from][sender]
            )
        ) return;
        // The sender should have enough balance
        if (mirror_balanceOf[from][id] < amount) return;

        vm.prank(sender);
        mockERC1155A.safeTransferFrom(from, to, id, amount, data);

        /// Check state changes
        // If the caller is not owner and it's not approved for all, allowance should be decreased
        if (sender != from && !mirror_isApprovedForAll[from][sender]) {
            assert(mockERC1155A.allowance(from, sender, id) == mirror_allowances[from][sender][id] - amount);
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

        /// Discard inputs that don't meet pre-conditions
        // Lengths should match
        if (ids.length != amounts.length) return;

        // Is the sender the owner, or is it approved for all?
        bool singleApproval = sender != from && !mirror_isApprovedForAll[from][sender];
        for (uint256 i; i < ids.length; i++) {
            // If the caller is not the owner and it's not approved for all, allowance should be >= amount
            if (!implies(singleApproval, mirror_allowances[from][sender][ids[i]] >= amounts[i])) return;
            // The sender should have enough balance
            if (mirror_balanceOf[from][ids[i]] < amounts[i]) return;
        }

        vm.prank(sender);
        mockERC1155A.safeBatchTransferFrom(from, to, ids, amounts, data);

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // If the caller is not owner and it's not approved for all, allowance should be decreased
            if (singleApproval) {
                assert(
                    mockERC1155A.allowance(from, sender, ids[i]) == mirror_allowances[from][sender][ids[i]] - amounts[i]
                );
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

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;

        vm.prank(sender);
        mockERC1155A.setApprovalForOne(spender, id, amount);

        /// Check state changes
        assert(mockERC1155A.allowance(sender, spender, id) == amount);

        /// Update mirrors
        _updateSingleAllowanceMirror(sender, spender, id, amount);
    }

    function increaseAllowance(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 addedValue) public {
        (address sender, address spender, uint256 id) =
            mockERC1155A_prepare_increaseAllowance(senderSeed, spenderSeed, idSeed);

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;

        vm.prank(sender);
        bool success = mockERC1155A.increaseAllowance(spender, id, addedValue);
        assert(success);

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

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;
        // Allowance should be enough
        if (mirror_allowances[sender][spender][id] < subtractedValue) return;

        vm.prank(sender);
        bool success = mockERC1155A.decreaseAllowance(spender, id, subtractedValue);
        assert(success);

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

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;
        if (ids.length != amounts.length) return; // not done explicitly in the contract but would revert if not

        vm.prank(sender);
        mockERC1155A.setApprovalForMany(spender, ids, amounts);

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

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;
        if (ids.length != addedValues.length) return; // not done explicitly but would revert if not

        vm.prank(sender);
        bool success = mockERC1155A.increaseAllowanceForMany(spender, ids, addedValues);
        assert(success);

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

        /// Discard inputs that don't meet pre-conditions
        if (sender == address(0) || spender == address(0)) return;
        if (ids.length != subtractedValues.length) return; // not done explicitly but would revert if not

        for (uint256 i; i < ids.length; i++) {
            if (mirror_allowances[sender][spender][ids[i]] < subtractedValues[i]) return;
        }

        vm.prank(sender);
        bool success = mockERC1155A.decreaseAllowanceForMany(spender, ids, subtractedValues);
        assert(success);

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

        /// Discard inputs that don't meet pre-conditions
        // The token should not be registered yet
        if (mirror_aERC20Tokens[id] != address(0)) return;
        // There should be at least one unit circulating for this id
        if (mirror_totalSupply[id] == 0) return;

        address token = mockERC1155A.registerAERC20(id);

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

        /// Discard inputs that don't meet pre-conditions
        if (ids.length != amounts.length) return;
        if (owner == address(0)) return; // condition in aERC20 `mint()`
        bool singleApproval = sender != owner && !mirror_isApprovedForAll[owner][sender];

        for (uint256 i; i < ids.length; i++) {
            // If the caller is not the owner and it's not approved for all, allowance should be >= amount
            if (!implies(singleApproval, mirror_allowances[owner][sender][ids[i]] >= amounts[i])) return;
            // The sender should have enough balance
            if (mirror_balanceOf[owner][ids[i]] < amounts[i]) return;
            // The token should be registered already
            if (mirror_aERC20Tokens[ids[i]] == address(0)) return;
        }

        vm.prank(sender);
        mockERC1155A.transmuteBatchToERC20(owner, ids, amounts);

        /// Check state changes
        for (uint256 i; i < ids.length; i++) {
            // If the caller is not owner and it's not approved for all, allowance should be decreased
            if (singleApproval) {
                assert(
                    mockERC1155A.allowance(owner, sender, ids[i])
                        == mirror_allowances[owner][sender][ids[i]] - amounts[i]
                );
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

        /// Discard inputs that don't meet pre-conditions
        if (ids.length != amounts.length) return; // not done explicitly in the contract but would revert if not
        if (owner == address(0)) return; // condition in aERC20 `burn()`

        for (uint256 i; i < ids.length; i++) {
            // The sender should have enough balance
            if (mirror_aERC20_balanceOf[owner][ids[i]] < amounts[i]) return;
            // The token should be registered already
            if (mirror_aERC20Tokens[ids[i]] == address(0)) return;
        }

        vm.prank(sender);
        mockERC1155A.transmuteBatchToERC1155A(owner, ids, amounts);

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

        /// Discard inputs that don't meet pre-conditions
        if (owner == address(0)) return; // condition in aERC20 `mint()`
        bool singleApproval = sender != owner && !mirror_isApprovedForAll[owner][sender];

        // If the caller is not the owner and it's not approved for all, allowance should be >= amount
        if (!implies(singleApproval, mirror_allowances[owner][sender][id] >= amount)) return;
        // The sender should have enough balance
        if (mirror_balanceOf[owner][id] < amount) return;
        // The token should be registered already
        if (mirror_aERC20Tokens[id] == address(0)) return;

        vm.prank(sender);
        mockERC1155A.transmuteToERC20(owner, id, amount);

        /// Check state changes
        // If the caller is not owner and it's not approved for all, allowance should be decreased
        if (singleApproval) {
            assert(mockERC1155A.allowance(owner, sender, id) == mirror_allowances[owner][sender][id] - amount);
        }
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

        /// Discard inputs that don't meet pre-conditions
        if (owner == address(0)) return; // condition in aERC20 `burn()`
        // The sender should have enough balance
        if (mirror_aERC20_balanceOf[owner][id] < amount) return;
        // The token should be registered already
        if (mirror_aERC20Tokens[id] == address(0)) return;

        vm.prank(sender);
        mockERC1155A.transmuteToERC1155A(owner, id, amount);

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

    /// @dev Discriminate address zero (otherwise minting ERC1155-A tokens will revert)
    /// @dev Discriminate cases where it would try to mint to a `to` address that somehow has some code
    /// "unknown selector `0xf23a6e61` for VmCalls"; which is `onERC1155Received`.
    function _selectRandomOrCreateUser(uint256 seed) internal override returns (address user) {
        // return super._selectRandomOrCreateUser(seed == 0 ? seed + 1 : seed);
        uint256 chanceToSelectExistingUser = 30; // 30%

        if (seed % 100 < chanceToSelectExistingUser && _users.length > 0) {
            user = _users[seed % _users.length];
        } else {
            user = address(uint160(seed));

            // Additional discriminate logic
            if (user == address(0) || user.code.length > 0) {
                user = address(1);
            }

            // Does it exist already?
            for (uint256 i = 0; i < _users.length; i++) {
                if (_users[i] == user) {
                    return user;
                }
            }

            // If not, add it to the list
            _users.push(user);

            // Select a token id
            uint256 tokenId = _selectRandomOrInexistentTokenId(seed);

            // Fund the user
            uint256 amount = bound(seed, 1, uint256(type(uint96).max));
            mockERC1155A.mint(user, tokenId, amount, "");
            _updateSingleBalancesMirror(address(0), user, tokenId, amount, true);
        }
    }

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
