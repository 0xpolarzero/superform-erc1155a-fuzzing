// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { MockERC1155A } from "test/mocks/MockERC1155A.sol";

/// @dev Base handler to be implemented by specific handlers

abstract contract Handler_Base is Test {
    MockERC1155A mockERC1155A;

    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Users that interacted with the contract
    address[] internal _users;
    /// @dev ERC1155A Tokens that were minted
    uint256[] internal _tokenIds;
    /// @dev aERC20 tokens that were registered (ids)
    uint256[] internal _aERC20TokenIds;

    /* ---------------------------------- BASE ---------------------------------- */

    /// @dev Mirror totalSupply for each id
    mapping(uint256 id => uint256 supply) public mirror_totalSupply;
    /// @dev Mirror balance for each id
    mapping(address account => mapping(uint256 id => uint256 balance)) public mirror_balanceOf;
    /// @dev Mirror allowance for each id
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 allowance))) public
        mirror_allowances;
    /// @dev Mirror isApprovedForAll for each id
    mapping(address owner => mapping(address spender => bool isApprovedForAll)) public mirror_isApprovedForAll;

    /* ------------------------------ TRANSMUTATION ----------------------------- */

    /// @dev Mirror registered aERC20 for each id
    mapping(uint256 id => address aERC20TokenId) public mirror_aERC20Tokens;

    /// @dev Mirror aERC20 balances for each id
    mapping(address account => mapping(uint256 id => uint256 balance)) public mirror_aERC20_balanceOf;

    /* -------------------------------------------------------------------------- */
    /*                                  FUNCTIONS                                 */
    /* -------------------------------------------------------------------------- */
    /* ------------------------------- CONSTRUCTOR ------------------------------ */

    constructor(MockERC1155A _mockERC1155A) {
        mockERC1155A = _mockERC1155A;
    }

    /* ----------------------------- ERC1155-A LOGIC ---------------------------- */

    function mockERC1155A_prepare_safeTransferFrom(
        uint256 senderSeed,
        uint256 fromSeed,
        uint256 toSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address from, address to, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        from = _selectRandomOrCreateUser(fromSeed);
        to = _selectRandomOrCreateUser(toSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    /* ------------------------------ ERC1155 LOGIC ----------------------------- */

    function mockERC1155A_prepare_setApprovalForAll(
        uint256 senderSeed,
        uint256 operatorSeed
    )
        internal
        returns (address sender, address operator)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        operator = _selectRandomOrCreateUser(operatorSeed);
    }

    function mockERC1155A_prepare_safeBatchTransferFrom(
        uint256 senderSeed,
        uint256 fromSeed,
        uint256 toSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address from, address to, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        from = _selectRandomOrCreateUser(fromSeed);
        to = _selectRandomOrCreateUser(toSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    /* ----------------------------- SINGLE APPROVE ----------------------------- */

    function mockERC1155A_prepare_setApprovalForOne(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address spender, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    function mockERC1155A_prepare_increaseAllowance(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address spender, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    function mockERC1155A_prepare_decreaseAllowance(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address spender, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    /* ------------------------------ MULTI APPROVE ----------------------------- */

    function mockERC1155A_prepare_setApprovalForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address spender, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    function mockERC1155A_prepare_increaseAllowanceForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address spender, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    function mockERC1155A_prepare_decreaseAllowanceForMany(
        uint256 senderSeed,
        uint256 spenderSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address spender, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        spender = _selectRandomOrCreateUser(spenderSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    /* --------------------------- AERC20 & TRANSMUTE --------------------------- */

    function mockERC1155A_prepare_registerAERC20(uint256 idSeed) internal returns (uint256 id) {
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    function mockERC1155A_prepare_transmuteBatchToERC20(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address owner, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        owner = _selectRandomOrCreateUser(ownerSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    function mockERC1155A_prepare_transmuteBatchToERC1155A(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256[] memory idSeeds
    )
        internal
        returns (address sender, address owner, uint256[] memory ids)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        owner = _selectRandomOrCreateUser(ownerSeed);
        ids = _selectRandomOrInexistentTokenIdMulti(idSeeds);
    }

    function mockERC1155A_prepare_transmuteToERC20(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address owner, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        owner = _selectRandomOrCreateUser(ownerSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    function mockERC1155A_prepare_transmuteToERC1155A(
        uint256 senderSeed,
        uint256 ownerSeed,
        uint256 idSeed
    )
        internal
        returns (address sender, address owner, uint256 id)
    {
        sender = _selectRandomOrCreateUser(senderSeed);
        owner = _selectRandomOrCreateUser(ownerSeed);
        id = _selectRandomOrInexistentTokenId(idSeed);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  UTILITIES                                 */
    /* -------------------------------------------------------------------------- */

    function implies(bool a, bool b) internal pure returns (bool) {
        return !a || b;
    }

    function assert_implies(bool a, bool b) internal pure {
        assert(implies(a, b));
    }

    /* -------------------------------------------------------------------------- */
    /*                                   HELPERS                                  */
    /* -------------------------------------------------------------------------- */

    function _selectRandomOrCreateUser(uint256 seed) internal virtual returns (address user) {
        uint256 chanceToSelectExistingUser = 30; // 30%

        if (seed % 100 < chanceToSelectExistingUser && _users.length > 0) {
            user = _users[seed % _users.length];
        } else {
            user = address(uint160(seed));

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

    function _selectRandomOrInexistentTokenId(uint256 seed) internal virtual returns (uint256 tokenId) {
        uint256 chanceToSelectExistingTokenId = 30; // 30%

        if (seed % 100 < chanceToSelectExistingTokenId && _tokenIds.length > 0) {
            tokenId = _tokenIds[seed % _tokenIds.length];
        } else {
            tokenId = seed;
            // Does it exist already?
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                if (_tokenIds[i] == tokenId) {
                    return tokenId;
                }
            }

            // If not, add it to the list
            _tokenIds.push(tokenId);
        }
    }

    function _selectRandomOrInexistentTokenIdMulti(uint256[] memory seeds)
        internal
        virtual
        returns (uint256[] memory ids)
    {
        ids = new uint256[](seeds.length);

        for (uint256 i = 0; i < seeds.length; i++) {
            ids[i] = _selectRandomOrInexistentTokenId(seeds[i]);
        }
    }

    /* -------------------------------- BALANCES -------------------------------- */

    function _updateSingleBalancesMirror(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bool initialMint
    )
        internal
        virtual
    {
        if (from != address(0)) {
            mirror_balanceOf[from][id] -= amount;
        }
        if (to != address(0)) {
            mirror_balanceOf[to][id] += amount;
        }

        if (initialMint) {
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
        virtual
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
        virtual
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
        virtual
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
        virtual
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
        virtual
    {
        for (uint256 i = 0; i < id.length; i++) {
            mirror_allowances[owner][spender][id[i]] -= subtractedValues[i];
        }
    }

    function _updateApprovalForAllMirror(address owner, address spender, bool approved) internal virtual {
        mirror_isApprovedForAll[owner][spender] = approved;
    }

    /* ------------------------------ TRANSMUTATION ----------------------------- */

    function _setAERC20TokenIdMirror(uint256 id, address aToken) internal virtual {
        mirror_aERC20Tokens[id] = aToken;
        _aERC20TokenIds.push(id);
    }

    function _updateSingleTransmutedToERC20Mirror(address owner, uint256 id, uint256 amount) internal virtual {
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
        virtual
    {
        for (uint256 i = 0; i < ids.length; i++) {
            mirror_balanceOf[owner][ids[i]] -= amounts[i];
            mirror_totalSupply[ids[i]] -= amounts[i];
            mirror_aERC20_balanceOf[owner][ids[i]] += amounts[i];
        }
    }

    function _updateSingleTransmutedToERC1155AMirror(address owner, uint256 id, uint256 amount) internal virtual {
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
        virtual
    {
        for (uint256 i = 0; i < ids.length; i++) {
            mirror_balanceOf[owner][ids[i]] += amounts[i];
            mirror_totalSupply[ids[i]] += amounts[i];
            mirror_aERC20_balanceOf[owner][ids[i]] -= amounts[i];
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                   GETTERS                                  */
    /* -------------------------------------------------------------------------- */

    function users() external view returns (address[] memory) {
        return _users;
    }

    function tokenIds() external view returns (uint256[] memory) {
        return _tokenIds;
    }

    function aERC20TokenIds() external view returns (uint256[] memory) {
        return _aERC20TokenIds;
    }
}
