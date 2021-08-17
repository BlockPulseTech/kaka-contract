// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../interface/Ikaka721.sol";
import "../interface/Ikaka1155.sol";

contract KAKACardUpgrade is Context, ERC721Holder, ERC1155Holder {
    address public owner;
    bool public status;

    IKTN public newKTN;
    IKTA public newKTA;

    IKTN public oldKTN;
    IKTA public oldKTA;

    constructor(){
        owner = _msgSender();
    }

    modifier onlyOwner {
        require(_msgSender() == owner, "owner only!");
        _;
    }

    modifier onlyOpen {
        require(status, "not open");
        _;
    }

    function setOldAddr(address oldKTN_, address oldKTA_) public onlyOwner {
        oldKTN = IKTN(oldKTN_);
        oldKTA = IKTA(oldKTA_);
    }

    function setNewAddr(address newKTN_, address newKTA_) public onlyOwner {
        newKTN = IKTN(newKTN_);
        newKTA = IKTA(newKTA_);
    }

    function open() public onlyOwner {
        require(!status,"opened");
        status = true;
    }

    function close() public onlyOwner {
        require(status,"closed");
        status = false;
    }

    function exchange721(uint[] memory ids_) public onlyOpen returns (bool) {
        for (uint i = 0; i < ids_.length; ++i) {
            uint tokenId = ids_[i];
            uint cardId = oldKTA.cardIdMap(tokenId);
            oldKTA.safeTransferFrom(_msgSender(), address(this), tokenId);
            newKTA.mint(_msgSender(), cardId);
        }
        return true;
    }

    function exchange1155(uint[] memory ids_, uint[] memory values_) public onlyOpen returns (bool) {
        oldKTN.safeBatchTransferFrom(_msgSender(), address(this), ids_, values_, "");
        newKTN.mintBatch(_msgSender(), ids_, values_);
        return true;
    }

    function setOldKTAApprovalForAll(address account_) public onlyOwner {
        oldKTA.setApprovalForAll(account_, true);
    }

    function setOldKTNApprovedForAll(address account_) public onlyOwner {
        oldKTN.setApprovalForAll(account_, true);
    }
}