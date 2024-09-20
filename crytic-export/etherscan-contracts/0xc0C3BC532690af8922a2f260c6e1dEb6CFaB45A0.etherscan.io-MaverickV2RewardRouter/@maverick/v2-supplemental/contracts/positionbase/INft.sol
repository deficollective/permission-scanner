// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface INft is IERC721Enumerable {
    /**
     * @notice Check if an NFT exists for a given owner and index.
     */
    function tokenOfOwnerByIndexExists(address owner, uint256 index) external view returns (bool);

    /**
     * @notice Return Id of the next token minted.
     */
    function nextTokenId() external view returns (uint256 nextTokenId_);

    /**
     * @notice Check if the caller has access to a specific NFT by tokenId.
     */
    function checkAuthorized(address spender, uint256 tokenId) external view returns (address owner);

    /**
     * @notice List of tokenIds by owner.
     */
    function tokenIdsOfOwner(address owner) external view returns (uint256[] memory tokenIds);

    /**
     * @notice Get the token URI for a given tokenId.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}
