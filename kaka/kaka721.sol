// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KAKACard721 is Ownable, ERC721Enumerable, ERC721URIStorage{
    // for inherit
    function _burn (uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        ERC721._burn(tokenId);
    }
    function _beforeTokenTransfer (address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return interfaceId == type(IERC721).interfaceId
        || interfaceId == type(IERC721Enumerable).interfaceId
        || interfaceId == type(IERC721Metadata).interfaceId
        || super.supportsInterface(interfaceId);
    }


    using SafeMath for uint;
    using Address for address;
    using Strings for uint256;

    mapping(address => mapping(uint => uint)) public minters;
    address public superMinter;

    function setSuperMinter(address newSuperMinter_) public onlyOwner {
        superMinter = newSuperMinter_;
    }

    function setMinter(address newMinter_, uint cardId_, uint amount_) public onlyOwner {
        minters[newMinter_][cardId_] = amount_;
    }


    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct CardInfo {
        uint cardId;
        string name;
        uint currentAmount;
        uint burnedAmount;
        uint maxAmount;
        string tokenURI;
    }

    mapping(uint => CardInfo) public cardInfoes;
    mapping(uint => uint) public cardIdMap;
    string public myBaseURI;

    constructor(string memory name_, string memory symbol_, string memory myBaseURI_) ERC721(name_, symbol_) {
        myBaseURI = myBaseURI_;
    }

    function setMyBaseURI(string memory uri_) public onlyOwner {
        myBaseURI = uri_;
    }

    function setTokenURI(uint256 tokenId_, string memory tokenURI_) public onlyOwner returns (bool) {
        _setTokenURI(tokenId_, tokenURI_);
        return true;
    }

    function newCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_) public onlyOwner {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == 0, "K: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : 0,
        burnedAmount : 0,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function newBurnedCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_, uint burnedAmount_) public onlyOwner {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == 0, "K: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : 0,
        burnedAmount : burnedAmount_,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function editCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_) public onlyOwner {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == cardId_, "K: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : cardInfoes[cardId_].currentAmount,
        burnedAmount : cardInfoes[cardId_].burnedAmount,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function editURITypeBatch(uint[] calldata ids_ , bool[] calldata types_) public onlyOwner returns (bool) {
        require(ids_.length > 0 && ids_.length == types_.length,"ids and amounts length mismatch");
        for (uint i = 0; i < ids_.length; ++i) {
            if (types_[i]) {
                _setTokenURI(ids_[i], ids_[i].toString());
            } else {
                _setTokenURI(ids_[i], "");
            }
        }
        return true;
    }

    function mint(address player_, uint cardId_, bool uriInTokenId_) public returns (uint256) {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId != 0, "K: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][cardId_] > 0, "K: not minter");
            minters[_msgSender()][cardId_] -= 1;
        }

        require(cardInfoes[cardId_].currentAmount < cardInfoes[cardId_].maxAmount, "k: amount out of limit");
        cardInfoes[cardId_].currentAmount += 1;

        _tokenIds.increment();
        uint tokenId = _tokenIds.current();

        cardIdMap[tokenId] = cardId_;
        _mint(player_, tokenId);

        if (uriInTokenId_) {
            _setTokenURI(tokenId, tokenId.toString());
        }

        return tokenId;
    }

    function mintMulti(address player_, uint cardId_, uint amount_, bool uriInTokenId_) public returns (uint256) {
        require(amount_ > 0, "K: missing amount");
        require(cardId_ != 0 && cardInfoes[cardId_].cardId != 0, "K: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][cardId_] >= amount_, "K: not minter");
            minters[_msgSender()][cardId_] -= amount_;
        }

        require(cardInfoes[cardId_].maxAmount.sub(cardInfoes[cardId_].currentAmount) >= amount_, "K: amount out of limit");
        cardInfoes[cardId_].currentAmount += amount_;

        uint tokenId;

        for (uint i = 0; i < amount_; ++i) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();

            cardIdMap[tokenId] = cardId_;
            _mint(player_, tokenId);

            if (uriInTokenId_) {
                _setTokenURI(tokenId, tokenId.toString());
            }
        }
        return tokenId;
    }

    function mintBatch(address player_, uint[] calldata ids_, uint[] calldata amounts_, bool uriInTokenId_) public returns (bool) {
        require(ids_.length > 0 && ids_.length == amounts_.length,"ids and amounts length mismatch");
        for (uint i = 0; i < ids_.length; ++i) {
            mintMulti(player_, ids_[i], amounts_[i], uriInTokenId_);
        }
        return true;
    }

    uint public burned;

    function burn(uint tokenId_) public returns (bool){
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "K: burner isn't owner");

        uint cardId = cardIdMap[tokenId_];
        cardInfoes[cardId].burnedAmount += 1;
        burned += 1;

        _burn(tokenId_);
        return true;
    }

    function burnMulti(uint[] calldata tokenIds_) public returns (bool){
        for (uint i = 0; i < tokenIds_.length; ++i) {
            uint tokenId_ = tokenIds_[i];
            require(_isApprovedOrOwner(_msgSender(), tokenId_), "K: burner isn't owner");

            uint cardId = cardIdMap[tokenId_];
            cardInfoes[cardId].burnedAmount += 1;

            _burn(tokenId_);
        }
        burned += tokenIds_.length;
        return true;
    }

    function tokenURI(uint256 tokenId_) override(ERC721URIStorage, ERC721) public view returns (string memory) {
        require(_exists(tokenId_), "K: nonexistent token");

        string memory tURI = super.tokenURI(tokenId_);
        string memory cURI = cardInfoes[cardIdMap[tokenId_]].tokenURI;
        string memory base = _myBaseURI();

        if (bytes(tURI).length > 0) {
            return string(abi.encodePacked(base, cURI, "/", tURI));
        } else {
            return string(abi.encodePacked(base, cURI));
        }
    }

    function _myBaseURI() internal view returns (string memory) {
        return myBaseURI;
    }
}
