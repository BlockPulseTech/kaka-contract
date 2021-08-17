// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "../interface/Ikaka721.sol";
import "../interface/Idodo.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract DODOConvert is ERC721Holder{
    address public owner;
    address public dodo;
    address public kaka;

    mapping(uint => uint) public dodo_to_kaka;

    constructor(){
        owner = msg.sender;

        dodo_to_kaka[78] = 20001;
        dodo_to_kaka[79] = 20002;
        dodo_to_kaka[80] = 20003;
        dodo_to_kaka[81] = 20004;
        dodo_to_kaka[82] = 20005;
        dodo_to_kaka[83] = 20006;
        dodo_to_kaka[84] = 20007;
        dodo_to_kaka[85] = 20008;
        dodo_to_kaka[86] = 20009;
        dodo_to_kaka[87] = 20010;
        dodo_to_kaka[88] = 20011;
    }

    modifier onlyOwner{
        require(msg.sender==owner,"owner only!");
        _;
    }

    function setAddr(address _dodo, address _kaka)public onlyOwner{
        dodo = _dodo;
        kaka = _kaka;
    }

    function transferOwnership(address _newowner) external onlyOwner{
        owner = _newowner;
    }

    event Swap(address indexed _user, uint _tokenIdDODO, uint _tokenIdKAKA);

    // token id => card Id
    function convertID(uint tokenId_) public pure returns(uint){
        require(tokenId_>=1 && tokenId_<=5337,"token id does not exist");
        if(1<=tokenId_ && tokenId_ <=1000){
            return 78;
        }
        else if(tokenId_ <= 1735){return 79;}
        else if(tokenId_ <= 2445){return 80;}
        else if(tokenId_ <= 3150){return 81;}
        else if(tokenId_ <= 3850){return 82;}
        else if(tokenId_ <= 4465){return 83;}
        else if(tokenId_ <= 4743){return 84;}
        else if(tokenId_ <= 5036){return 85;}
        else if(tokenId_ <= 5329){return 86;}
        else if(tokenId_ <= 5334){return 87;}
        else if(tokenId_ <= 5337){return 88;}

        return 0;
    }

    // input DODO tokenid, determine the card id and corresponding kaka id
    function swap(uint tokenId_) public{
        require(IDODO(dodo).ownerOf(tokenId_) == msg.sender,"Not the owner of this card");
        IDODO(dodo).safeTransferFrom(msg.sender, address(this), tokenId_);

        uint cid = convertID(tokenId_);
        uint new_cid = dodo_to_kaka[cid];

        uint tokenId_new = IKTA(kaka).mint(msg.sender, new_cid);
        emit Swap(msg.sender, tokenId_, tokenId_new);
    }



    function swapBatch(uint[] memory tids) public {
        for(uint i=0; i < tids.length; i++){
            swap(tids[i]);
        }
    }

    /*
    * for the 6 wrongly swapped cards to recall and re-mint new cards
    */
    function swapWrongIds(uint tokenId_) public{
        require(tokenId_ == 1133 || 
        tokenId_ == 1160 || 
        tokenId_ == 1193 || 
        tokenId_ == 1272 ||
        tokenId_ == 1313 ||
        tokenId_ == 1333,"must be one of 6 token ids");

        require(IKTA(kaka).ownerOf(tokenId_) == msg.sender,"Not the owner of this card");
        uint cid = IKTA(kaka).cardIdMap(tokenId_);
        require(cid == 20006, "not this one");

        // recall a Spider man
        IKTA(kaka).safeTransferFrom(msg.sender, address(this), tokenId_);

        // mint a new Thor 
        uint tokenId_new = IKTA(kaka).mint(msg.sender, 20007);
        emit Swap(msg.sender, tokenId_, tokenId_new);
    }


}