// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IKAKA {

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;


    function cardIdMap(uint _tid) external view returns (uint _cid);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);


}

contract repurchaser is ERC721Holder {

    using SafeMath for uint;
    address public owner;
    IKAKA kaka;

    uint public counter;
    mapping(uint => uint) public num_repo; // cid => amount repurchased
    uint public moneyUsed; // money used for repurchase


    bool public isOpen; // switch for repo
    mapping(uint => bool) public isCidOpen; // check if card id supports repo
    mapping(uint => uint) public cidAllowance; // cid => allowed max repo amount
    mapping(uint => uint) public repoPrice; // cid => price

    event Repurchase(address indexed _user, uint _tid, uint _cid, uint price);

    constructor(address KTA_){
        owner = msg.sender;
        kaka = IKAKA(KTA_);
    }

    modifier onlyOwner{
        require(owner == msg.sender, "only owner");
        _;
    }

    modifier isActive{
        require(isOpen, "repurchase function not active");
        _;
    }

    function transferOwnership(address newowner) public onlyOwner {
        owner = newowner;
    }

    // check whether a token id is valid for repo, if false, ether non-exist id or not open
    function isValid(uint _tid) public view returns (bool){
        uint _cid = kaka.cardIdMap(_tid);
        return isCidOpen[_cid];
    }

    function hasApproved(address _user, uint _tid) public view returns (bool){
        return (kaka.isApprovedForAll(_user, address(this)) || kaka.getApproved(_tid) == address(this));
    }

    function setCidOpen(uint[] calldata _cid, bool[] calldata _isOpen) public onlyOwner {
        for (uint i = 0; i < _cid.length; i++) {
            isCidOpen[_cid[i]] = _isOpen[i];
        }
    }

    function setPrice(uint[] calldata _cids, uint[] calldata _prices) public onlyOwner {
        require(_cids.length == _prices.length, "two array should be of equal length");
        for (uint i = 0; i < _cids.length; i++) {
            repoPrice[_cids[i]] = _prices[i];
        }
    }

    function setCidAllowance(uint[] calldata _cids, uint[] calldata _allownace) public onlyOwner {
        require(_cids.length == _allownace.length, "two array should be of equal length");
        for (uint i = 0; i < _cids.length; i++) {
            cidAllowance[_cids[i]] = _allownace[i];
        }
    }

    function repurchase(uint _tid) external isActive {
        uint _cid = kaka.cardIdMap(_tid);
        require(_cid != 0, "token id does not exist");
        require(msg.sender == kaka.ownerOf(_tid));

        require(isCidOpen[_cid], "not open yet");
        require(cidAllowance[_cid] > 0, "no allowance for this cid!!!");
        require(kaka.getApproved(_tid) == address(this) || kaka.isApprovedForAll(kaka.ownerOf(_tid), address(this)), "approve first");

        uint price = repoPrice[_cid].mul(95).div(100);

        num_repo[_cid] = num_repo[_cid] + 1;
        counter = counter + 1;
        cidAllowance[_cid] = cidAllowance[_cid] - 1;
        moneyUsed = moneyUsed.add(price);

        kaka.transferFrom(msg.sender, address(this), _tid);
        payable(msg.sender).transfer(price);

        emit Repurchase(msg.sender, _tid, _cid, repoPrice[_cid]);
    }

    function safePull(address payable _account) public onlyOwner {
        payable(_account).transfer(getBalance());
    }

    // owner can pause or resume
    function setOpen(bool b) public onlyOwner {
        isOpen = b;
    }

    function setApprovalForAll(address _account) public onlyOwner {
        kaka.setApprovalForAll(_account, true);
    }

    receive() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

}