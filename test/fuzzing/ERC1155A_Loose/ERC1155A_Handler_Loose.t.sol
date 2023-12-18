// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test, console } from "forge-std/Test.sol";

import { Handler_Base } from "test/fuzzing/Handler_Base.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";

/// @dev Here we perform most assertions with mirrors, for more fine-grained control;
/// then we verify the correctness of the mirrors as an invariant.
/// @dev Basically, the flaw is:
/// - call the contract with some random input;
/// - update the mirrors as they should be updated, if the call was successful.
/// @dev See `ERC1155A_Handler_Strict` for a... stricter version of updates and assertions,
/// which more straightforwardly addresses the assumptions.

contract ERC1155A_Handler_Loose is Handler_Base {
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

        _updateSingleBalancesMirror(from, to, id, amount, false);
    }

    /* ------------------------------ ERC1155 LOGIC ----------------------------- */

    function setApprovalForAll(uint256 senderSeed, uint256 operatorSeed, bool approved) public {
        (address sender, address operator) = mockERC1155A_prepare_setApprovalForAll(senderSeed, operatorSeed);

        vm.prank(sender);
        mockERC1155A.setApprovalForAll(operator, approved);

        _updateApprovalForAllMirror(msg.sender, operator, approved);
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

        _updateMultiBalancesMirror(from, to, ids, amounts);
    }

    /* ----------------------------- SINGLE APPROVE ----------------------------- */

    function setApprovalForOne(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 amount) public {
        (address sender, address spender, uint256 id) =
            mockERC1155A_prepare_setApprovalForOne(senderSeed, spenderSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.setApprovalForOne(spender, id, amount);

        _updateSingleAllowanceMirror(msg.sender, spender, id, amount);
    }

    function increaseAllowance(uint256 senderSeed, uint256 spenderSeed, uint256 idSeed, uint256 addedValue) public {
        (address sender, address spender, uint256 id) =
            mockERC1155A_prepare_increaseAllowance(senderSeed, spenderSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.increaseAllowance(spender, id, addedValue);

        _updateSingleAllowanceMirror(msg.sender, spender, id, mirror_allowances[msg.sender][spender][id] + addedValue);
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
        mockERC1155A.decreaseAllowance(spender, id, subtractedValue);

        _updateSingleAllowanceMirror(
            msg.sender, spender, id, mirror_allowances[msg.sender][spender][id] - subtractedValue
        );
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

        _setMultiAllowancesMirror(msg.sender, spender, ids, amounts);
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
        mockERC1155A.increaseAllowanceForMany(spender, ids, addedValues);

        _increaseMultiAllowancesMirror(msg.sender, spender, ids, addedValues);
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
        mockERC1155A.decreaseAllowanceForMany(spender, ids, subtractedValues);

        _decreaseMultiAllowancesMirror(msg.sender, spender, ids, subtractedValues);
    }

    /* --------------------------- AERC20 & TRANSMUTE --------------------------- */

    function registerAERC20(uint256 idSeed) public {
        uint256 id = mockERC1155A_prepare_registerAERC20(idSeed);

        address token = mockERC1155A.registerAERC20(id);
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

        _updateMultiTransmutedToERC1155AMirror(owner, ids, amounts);
    }

    function transmuteToERC20(uint256 senderSeed, uint256 ownerSeed, uint256 idSeed, uint256 amount) public {
        (address sender, address owner, uint256 id) =
            mockERC1155A_prepare_transmuteToERC20(senderSeed, ownerSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.transmuteToERC20(owner, id, amount);

        _updateSingleTransmutedToERC20Mirror(owner, id, amount);
    }

    function transmuteToERC1155A(uint256 senderSeed, uint256 ownerSeed, uint256 idSeed, uint256 amount) public {
        (address sender, address owner, uint256 id) =
            mockERC1155A_prepare_transmuteToERC1155A(senderSeed, ownerSeed, idSeed);

        vm.prank(sender);
        mockERC1155A.transmuteToERC1155A(owner, id, amount);

        _updateSingleTransmutedToERC1155AMirror(owner, id, amount);
    }
}
