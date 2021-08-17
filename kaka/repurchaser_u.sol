// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../interface/Ikaka721.sol";




contract RepurchaserU is ERC721Holder, Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;


    IKTA public KTA;
    IERC20 public U;

    uint public counter;
    mapping(uint => uint) public num_repo; // cid => amount repurchased
    uint public moneyUsed; // money used for repurchase


    bool public isOpen; // switch for repo
    mapping(uint => bool) public isCidOpen; // check if card id supports repo
    mapping(uint => uint) public cidAllowance; // cid => allowed max repo amount
    mapping(uint => uint) public repoPrice; // cid => price

    event Repurchase(address indexed user, uint indexed tid, uint indexed cid, uint price);
    constructor() {
        KTA = IKTA(0x3565AC59Aa2127D4C45bd050b673fBe6202cd742);
        U = IERC20(0x55d398326f99059fF775485246999027B3197955);
    }
    modifier isActive {
        require(isOpen, "repurchase function not active");
        _;
    }

    // owner can pause or resume
    function setOpen(bool b) public onlyOwner {
        isOpen = b;
    }

    function setCidOpen(uint[] calldata cid_, bool[] calldata isOpen_) public onlyOwner {
        for (uint i = 0; i < cid_.length; i++) {
            isCidOpen[cid_[i]] = isOpen_[i];
        }
    }

    function setPrice(uint[] calldata cids_, uint[] calldata prices_) public onlyOwner {
        require(cids_.length == prices_.length, "two array should be of equal length");
        for (uint i = 0; i < cids_.length; i++) {
            repoPrice[cids_[i]] = prices_[i];
        }
    }

    function setCidAllowance(uint[] calldata cids_, uint[] calldata allownace_) public onlyOwner {
        require(cids_.length == allownace_.length, "two array should be of equal length");
        for (uint i = 0; i < cids_.length; i++) {
            cidAllowance[cids_[i]] = allownace_[i];
        }
    }
    // 提卡
    function setApprovalForAll(address account) public onlyOwner {
        KTA.setApprovalForAll(account, true);
    }
    // 提钱
    function safePull(address account) public onlyOwner {
        uint amounts = U.balanceOf(address(this));
        U.safeTransfer(account, amounts);
    }

    function repurchase(uint tid_) external isActive {
        uint cid = KTA.cardIdMap(tid_);
        require(cid != 0, "token id does not exist");
        require(_msgSender() == KTA.ownerOf(tid_));

        require(isCidOpen[cid], "not open yet");
        require(cidAllowance[cid] > 0, "no allowance for this cid!!!");
        require(KTA.getApproved(tid_) == address(this) || KTA.isApprovedForAll(KTA.ownerOf(tid_), address(this)), "approve first");

        uint price = repoPrice[cid].mul(95).div(100);

        num_repo[cid] = num_repo[cid] + 1;
        counter = counter + 1;
        cidAllowance[cid] = cidAllowance[cid] - 1;
        moneyUsed = moneyUsed.add(price);

        // 收卡
        KTA.safeTransferFrom(_msgSender(), address(this), tid_);
        // 打钱
        U.safeTransfer(_msgSender(), price);

        emit Repurchase(_msgSender(), tid_, cid, repoPrice[cid]);
    }


    function getBalance() public view returns (uint) {
        return U.balanceOf(address(this));
    }

    // check whether a token id is valid for repo, if false, ether non-exist id or not open
    function isValid(uint tid_) public returns (bool) {
        uint cid = KTA.cardIdMap(tid_);
        return isCidOpen[cid];
    }

    function hasApproved(address user_, uint tid_) public view returns (bool) {
        return (KTA.isApprovedForAll(user_, address(this)) || KTA.getApproved(tid_) == address(this));
    }

}