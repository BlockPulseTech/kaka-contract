// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../other/conflux_sponsor.sol";

contract KAKACard721Cfx is ERC721Enumerable, ERC721URIStorage{
    // for inherit
    function _burn (uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        ERC721URIStorage._burn(tokenId);
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

    address public KAKA;
    mapping(address => mapping(uint => uint)) public minters;
    address public superMinter;


    modifier onlyKAKA () {
        require(_msgSender() == KAKA, "not KAKA's calling");
        _;
    }

    function setKAKA(address newKAKA_) public onlyKAKA {
        KAKA = newKAKA_;
    }

    function setSuperMinter(address newSuperMinter_) public onlyKAKA {
        superMinter = newSuperMinter_;
    }

    function setMinter(address newMinter_, uint cardId_, uint amount_) public onlyKAKA {
        minters[newMinter_][cardId_] = amount_;
    }


    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    SponsorWhitelistControl public constant SPONSOR = SponsorWhitelistControl(address(0x0888000000000000000000000000000000000001));

    struct CardInfo {
        uint cardId;
        string name;
        uint currentAmount;
        uint maxAmount;
        string tokenURI;
    }

    mapping(uint => CardInfo) public cardInfoes;
    mapping(uint => uint) public cardIdMap;
    string public myBaseURI;

    constructor(address KAKA_, string memory name_, string memory symbol_, string memory myBaseURI_) ERC721(name_, symbol_) {
        KAKA = KAKA_;
        myBaseURI = myBaseURI_;

        // register all users as sponsees
        address[] memory users = new address[](1);
        users[0] = address(0);
        SPONSOR.addPrivilege(users);
    }

    function setMyBaseURI(string memory uri_) public onlyKAKA {
        myBaseURI = uri_;
    }

    function newCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_) public onlyKAKA {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == 0, "ERC721: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : 0,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function mint(address player_, uint cardId_) public returns (uint256) {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId != 0, "ERC721: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][cardId_] > 0, "ERC721: not minter's calling");
            minters[_msgSender()][cardId_] -= 1;
        }

        require(cardInfoes[cardId_].currentAmount < cardInfoes[cardId_].maxAmount, "ERC721: Token amount is out of limit");
        cardInfoes[cardId_].currentAmount += 1;

        _tokenIds.increment();
        uint tokenId = _tokenIds.current();

        cardIdMap[tokenId] = cardId_;
        _mint(player_, tokenId);

        return tokenId;
    }

    function mintMulti(address player_, uint cardId_, uint amount_) public returns (uint256) {
        require(amount_ > 0, "ERC721: missing amount");
        require(cardId_ != 0 && cardInfoes[cardId_].cardId != 0, "ERC721: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][cardId_] >= amount_, "ERC721: not minter's calling");
            minters[_msgSender()][cardId_] -= amount_;
        }

        require(cardInfoes[cardId_].maxAmount.sub(cardInfoes[cardId_].currentAmount) >= amount_, "ERC721: Token amount is out of limit");
        cardInfoes[cardId_].currentAmount += amount_;

        uint tokenId;

        for (uint i = 0; i < amount_; ++i) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();

            cardIdMap[tokenId] = cardId_;
            _mint(player_, tokenId);

        }

        return tokenId;

    }

    mapping(uint => uint) public burned;

    function burn(uint tokenId_) public returns (bool){
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC721: burn caller is not owner nor approved");

        uint cardId = cardIdMap[tokenId_];
        burned[cardId] = burned[cardId].add(1);

        delete cardIdMap[tokenId_];
        _burn(tokenId_);
        return true;
    }

    function burnMulti(uint[] calldata tokenIds_) public returns (bool){
        for (uint i = 0; i < tokenIds_.length; ++i) {
            uint tokenId_ = tokenIds_[i];
            require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC721: burn caller is not owner nor approved");

            uint cardId = cardIdMap[tokenId_];
            burned[cardId] = burned[cardId].add(1);

            delete cardIdMap[tokenId_];
            _burn(tokenId_);
        }
        return true;
    }

    function tokenURI(uint256 tokenId_) override(ERC721URIStorage, ERC721) public view returns (string memory) {
        require(_exists(tokenId_), "ERC721Metadata: URI query for nonexistent token");

        string memory URI = cardInfoes[cardIdMap[tokenId_]].tokenURI;
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, URI))
        : URI;
    }

    function _baseURI() internal view override returns (string memory) {
        return myBaseURI;
    }
}
