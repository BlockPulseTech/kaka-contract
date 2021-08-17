// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IDODO{
    function tokenURI(uint256 tokenId) external view returns(string memory);
    function getApproved(uint256 tokenId) external view returns(address operator);
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovalForAll(address owner, address operator) external view returns(bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external returns(address user);
}