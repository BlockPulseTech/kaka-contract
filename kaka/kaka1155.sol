// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract KAKACard1155 is ERC1155, ERC1155Burnable {
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

    function setMinterBatch(address newMinter_, uint[] memory cardIds_, uint[] memory amounts_) public onlyKAKA {
        for (uint i = 0; i < cardIds_.length; i++) {
            minters[newMinter_][cardIds_[i]] = amounts_[i];
        }
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private _name;
    string private _symbol;

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    struct CardInfo {
        uint cardId;
        string name;
        uint currentAmount;
        uint burnedAmount;
        uint maxAmount;
        string tokenURI;
    }

    mapping(uint => CardInfo) public cardInfoes;
    string public myBaseURI;

    constructor(address KAKA_, string memory name_, string memory symbol_, string memory myBaseURI_, string memory URI_) ERC1155(URI_) {
        KAKA = KAKA_;
        _name = name_;
        _symbol = symbol_;
        myBaseURI = myBaseURI_;
    }

    function setMyBaseURI(string memory uri_) public onlyKAKA {
        myBaseURI = uri_;
    }

    function newCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_) public onlyKAKA {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == 0, "ERC1155: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : 0,
        burnedAmount : 0,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function newBurnedCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_, uint burnedAmount_) public onlyKAKA {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == 0, "ERC1155: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : 0,
        burnedAmount : burnedAmount_,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function editCard(string memory name_, uint cardId_, uint maxAmount_, string memory tokenURI_) public onlyKAKA {
        require(cardId_ != 0 && cardInfoes[cardId_].cardId == cardId_, "ERC721: wrong cardId");

        cardInfoes[cardId_] = CardInfo({
        cardId : cardId_,
        name : name_,
        currentAmount : cardInfoes[cardId_].currentAmount,
        burnedAmount : cardInfoes[cardId_].burnedAmount,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function mint(address to_, uint cardId_, uint amount_) public returns (bool) {
        require(amount_ > 0, "ERC1155: missing amount");
        require(cardId_ != 0 && cardInfoes[cardId_].cardId != 0, "ERC1155: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][cardId_] >= amount_, "ERC1155: not minter's calling");
            minters[_msgSender()][cardId_] -= amount_;
        }

        require(cardInfoes[cardId_].maxAmount.sub(cardInfoes[cardId_].currentAmount) >= amount_, "ERC1155: Token amount is out of limit");
        cardInfoes[cardId_].currentAmount += amount_;

        _mint(to_, cardId_, amount_, "");

        return true;
    }


    function mintBatch(address to_, uint256[] memory ids_, uint256[] memory amounts_) public returns (bool) {
        require(ids_.length == amounts_.length, "ERC1155: ids and amounts length mismatch");

        for (uint i = 0; i < ids_.length; i++) {
            require(ids_[i] != 0 && cardInfoes[ids_[i]].cardId != 0, "ERC1155: wrong cardId");

            if (superMinter != _msgSender()) {
                require(minters[_msgSender()][ids_[i]] >= amounts_[i], "ERC1155: not minter's calling");
                minters[_msgSender()][ids_[i]] -= amounts_[i];
            }

            require(cardInfoes[ids_[i]].maxAmount.sub(cardInfoes[ids_[i]].currentAmount) >= amounts_[i], "ERC1155: Token amount is out of limit");
            cardInfoes[ids_[i]].currentAmount += amounts_[i];
        }

        _mintBatch(to_, ids_, amounts_, "");

        return true;
    }


    uint public burnedCount;

    function burn(address account, uint256 id, uint256 value) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        cardInfoes[id].burnedAmount += 1;
        burnedCount = burnedCount.add(value);
        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        for (uint i = 0; i < ids.length; i++) {
            cardInfoes[i].burnedAmount += values[i];
            burnedCount = burnedCount.add(values[i]);
        }
        _burnBatch(account, ids, values);
    }

    function tokenURI(uint256 cardId_) public view returns (string memory) {
        require(cardInfoes[cardId_].cardId != 0, "ERC1155Metadata: URI query for nonexistent token");

        string memory URI = cardInfoes[cardId_].tokenURI;
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, URI))
        : URI;
    }

    function _baseURI() internal view returns (string memory) {
        return myBaseURI;
    }
}
