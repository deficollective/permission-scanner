// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {ERC721, IERC165} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {INft} from "./INft.sol";

/**
 * @notice Extensions to ECR-721 to support an image contract and owner
 * enumeration.
 */
abstract contract Nft is ERC721Enumerable, INft {
    uint256 private _nextTokenId = 1;

    constructor(string memory __name, string memory __symbol) ERC721(__name, __symbol) {}

    /**
     * @notice Internal function to mint a new NFT and assign it to the
     * specified address.
     * @param to The address to which the NFT will be minted.
     * @return tokenId The ID of the newly minted NFT.
     */
    function _mint(address to) internal returns (uint256 tokenId) {
        super._mint(to, _nextTokenId);
        tokenId = _nextTokenId++;
    }

    /**
     * @notice Modifier to restrict access to functions to the owner of a
     * specific NFT by its tokenId.
     */
    modifier onlyTokenIdAuthorizedUser(uint256 tokenId) {
        checkAuthorized(msg.sender, tokenId);
        _;
    }

    /// @inheritdoc INft
    function nextTokenId() public view returns (uint256 nextTokenId_) {
        return _nextTokenId;
    }

    /// @inheritdoc INft
    function tokenOfOwnerByIndexExists(address ownerToCheck, uint256 index) public view returns (bool exists) {
        return index < balanceOf(ownerToCheck);
    }

    /// @inheritdoc INft
    function tokenIdsOfOwner(address owner) public view returns (uint256[] memory tokenIds) {
        uint256 tokenCount = balanceOf(owner);
        tokenIds = new uint256[](tokenCount);
        for (uint256 k; k < tokenCount; k++) {
            tokenIds[k] = tokenOfOwnerByIndex(owner, k);
        }
    }

    /// @inheritdoc INft
    function checkAuthorized(address spender, uint256 tokenId) public view returns (address owner) {
        owner = ownerOf(tokenId);
        _checkAuthorized(owner, spender, tokenId);
    }

    // ************************************************************
    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function name() public view virtual override(INft, ERC721) returns (string memory) {
        return super.name();
    }

    function symbol() public view virtual override(INft, ERC721) returns (string memory) {
        return super.symbol();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(INft, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
