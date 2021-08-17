// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IKTN {
    function mintBatch(address to_, uint256[] memory ids_, uint256[] memory amounts_) external returns (bool);
    function safeBatchTransferFrom(address from_, address to_, uint256[] memory ids_, uint256[] memory amounts_, bytes memory data_) external;
    function setApprovalForAll(address operator, bool approved) external;
}
