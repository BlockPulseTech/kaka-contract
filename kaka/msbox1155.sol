// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract Msbox1155 is ERC1155, ERC1155Burnable {
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

    function setMinter(address newMinter_, uint boxId_, uint amount_) public onlyKAKA {
        minters[newMinter_][boxId_] = amount_;
    }

    function setMinterBatch(address newMinter_, uint[] memory boxIds_, uint[] memory amounts_) public onlyKAKA {
        for (uint i = 0; i < boxIds_.length; i++) {
            minters[newMinter_][boxIds_[i]] = amounts_[i];
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

    struct BoxInfo {
        uint boxId;
        string name;
        uint currentAmount;
        uint maxAmount;
        string tokenURI;
    }

    mapping(uint => BoxInfo) public boxInfoes;
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

    function newBox(string memory name_, uint boxId_, uint maxAmount_, string memory tokenURI_) public onlyKAKA {
        require(boxId_ != 0 && boxInfoes[boxId_].boxId == 0, "ERC1155: wrong boxId");

        boxInfoes[boxId_] = BoxInfo({
        boxId : boxId_,
        name : name_,
        currentAmount : 0,
        maxAmount : maxAmount_,
        tokenURI : tokenURI_
        });
    }

    function mint(address to_, uint boxId_, uint amount_) public returns (bool) {
        require(amount_ > 0, "ERC1155: missing amount");
        require(boxId_ != 0 && boxInfoes[boxId_].boxId != 0, "ERC1155: wrong boxId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][boxId_] >= amount_, "ERC1155: not minter's calling");
            minters[_msgSender()][boxId_] -= amount_;
        }

        require(boxInfoes[boxId_].maxAmount.sub(boxInfoes[boxId_].currentAmount) >= amount_, "ERC1155: Token amount is out of limit");
        boxInfoes[boxId_].currentAmount += amount_;

        _mint(to_, boxId_, amount_, "");

        return true;
    }


    function mintBatch(address to_, uint256[] memory ids_, uint256[] memory amounts_) public returns (bool) {
        require(ids_.length == amounts_.length, "ERC1155: ids and amounts length mismatch");

        for (uint i = 0; i < ids_.length; i++) {
            require(ids_[i] != 0 && boxInfoes[ids_[i]].boxId != 0, "ERC1155: wrong boxId");

            if (superMinter != _msgSender()) {
                require(minters[_msgSender()][ids_[i]] >= amounts_[i], "ERC1155: not minter's calling");
                minters[_msgSender()][ids_[i]] -= amounts_[i];
            }

            require(boxInfoes[ids_[i]].maxAmount.sub(boxInfoes[ids_[i]].currentAmount) >= amounts_[i], "ERC1155: Token amount is out of limit");
            boxInfoes[ids_[i]].currentAmount += amounts_[i];
        }

        _mintBatch(to_, ids_, amounts_, "");

        return true;
    }


    mapping(uint => uint) public burned;

    function burn(address account, uint256 id, uint256 value) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        burned[id] = burned[id].add(value);
        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        for (uint i = 0; i < ids.length; i++) {
            burned[ids[i]] = burned[ids[i]].add(values[i]);
        }
        _burnBatch(account, ids, values);
    }

    function tokenURI(uint256 boxId_) public view returns (string memory) {
        require(boxInfoes[boxId_].boxId != 0, "ERC1155Metadata: URI query for nonexistent token");

        string memory URI = boxInfoes[boxId_].tokenURI;
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, URI))
        : URI;
    }

    function _baseURI() internal view returns (string memory) {
        return myBaseURI;
    }
}
