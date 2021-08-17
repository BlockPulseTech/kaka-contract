// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../other/random_generator.sol";
import "../interface/Ikaka721.sol";
import "../interface/Imsbox1155.sol";

contract MysteryBoxS2 is RandomGenerator, Context {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Address for address;
    using Strings for uint256;

    address public owner;
    address public banker;

    // 售卖时间
    uint public saleStartTime;

    bool public isSale;
    bool public isOpenBox;

    uint public price;

    // 购买人数
    uint public total;
    mapping(address => bool) purchase_flag;

    // 一开
    mapping(uint => cardBagInfo) public firstCardBag;
    uint public firstCardBagCap;
    uint public firstCardAmount;

    // 二开
    mapping(uint => cardBagInfo) public secCardBag;
    uint public secCardBagCap;
    uint public secCardAmount;

    struct cardBagInfo {
        uint cardId;
        uint amount;
    }

    uint public msBoxKey = 3;
    Imsbox public Msbox;

    address public wallet;

    IERC20 public U;

    IKTA public KTA;

    uint public saleBoxAmount;
    uint public saleMaxNum;

    uint private _accSales_n;
    uint private _accSales_u;

    event BuyBox(address indexed user, uint cardId,uint amount);
    event OpenBox(address indexed user, uint indexed cardId, uint indexed tokenId);

    modifier onlyOwner () {
        require(_msgSender() == owner, "not owner's calling");
        _;
    }

    modifier saleStage () {
        require(isSale, "not sale stage");
        _;
    }

    modifier openBoxStage(){
        require(isOpenBox, "not openbox stage");
        _;
    }

    constructor(address KTA_, address Msbox_, address U_, address wallet_) {
        owner = _msgSender();
        KTA = IKTA(KTA_);
        Msbox = Imsbox(Msbox_);
        U = IERC20(U_);
        wallet = wallet_;

        price = 20 ether;

        uint[7] memory cardIds_ = [uint(50001), uint(50002), uint(50003), uint(50004), uint(50005), uint(50006), uint(50007)];
        uint[7] memory amounts_ = [uint(9), uint(19), uint(35), uint(100), uint(200), uint(300),uint(520)];
        firstCardBagCap = cardIds_.length;
        saleMaxNum = 1183;

        for (uint i = 0; i < firstCardBagCap; ++i) {
            firstCardBag[i] = cardBagInfo({
            cardId : cardIds_[i],
            amount : amounts_[i]
            });
            firstCardAmount = firstCardAmount.add(amounts_[i]);
        }

        uint[4] memory secCardIds_ = [uint(50001), uint(50002), uint(50003), uint(0)];
        uint[4] memory secAmounts_ = [uint(23), uint(45), uint(79), uint(973)];
        secCardBagCap = secCardIds_.length;

        for (uint i = 0; i < secCardBagCap; ++i) {
            secCardBag[i] = cardBagInfo({
            cardId : secCardIds_[i],
            amount : secAmounts_[i]
            });
            secCardAmount = secCardAmount.add(secAmounts_[i]);
        }
    }

    // only owner
    function transferOwnership(address com) public onlyOwner {
        owner = com;
    }

    function setSaleToken(address com) public onlyOwner {
        U = IERC20(com);
    }

    function setWallet(address com) public onlyOwner {
        wallet = com;
    }

    function setKTAAddr(address com) public onlyOwner {
        KTA = IKTA(com);
    }

    function setMsboxAddr(address com) public onlyOwner {
        Msbox = Imsbox(com);
    }

    function startSale() external onlyOwner {
        require(!isSale);
        saleStartTime = block.timestamp;
        isSale = true;
    }

    function stopSale() external onlyOwner saleStage {
        isSale = false;
    }

    function startOpenBox() external onlyOwner {
        require(!isOpenBox);
        isOpenBox = true;
    }

    function stopOpenBox() external onlyOwner openBoxStage {
        isOpenBox = false;
    }


    function viewSales() external view onlyOwner returns (uint n, uint u) {
        return (_accSales_n, _accSales_u);
    }

    function setBanker(address banker_) external onlyOwner {
        banker = banker_;
    }
    // only owner end

    function buyBox(uint amounts_) external saleStage returns (bool) {
        uint curSaleBox = saleBoxAmount.add(amounts_);
        require(curSaleBox <= saleMaxNum,"Out of limit");
        require(block.timestamp >= saleStartTime);

        U.safeTransferFrom(_msgSender(), wallet, amounts_.mul(price));
        Msbox.mint(_msgSender(), msBoxKey, amounts_);

        if (!purchase_flag[_msgSender()]) {
            purchase_flag[_msgSender()] = true;
            total = total.add(1);
        }

        saleBoxAmount = curSaleBox;
        _accSales_n += amounts_;
        _accSales_u += amounts_.mul(price);

        emit BuyBox(_msgSender(), msBoxKey, amounts_);
        return true;
    }

    function openBox() external openBoxStage returns (uint) {
        require(firstCardAmount >= 1, "Out of limit");

        Msbox.burn(_msgSender(), msBoxKey, 1);

        firstCardAmount = firstCardAmount.sub(1);
        uint level = _randomCardLevel();
        uint cardId = firstCardBag[level].cardId;
        uint tokenId = KTA.mint(_msgSender(), cardId);
        firstCardBag[level].amount = firstCardBag[level].amount.sub(1);
        emit OpenBox(_msgSender(), cardId, tokenId);
        return tokenId;
    }

    function openBoxBatch(uint amounts_) external openBoxStage returns (bool){
        require(firstCardAmount >= amounts_, "Out of limit");

        Msbox.burn(_msgSender(), msBoxKey, amounts_);
        firstCardAmount = firstCardAmount.sub(amounts_);

        uint level;
        uint cardId;
        uint tokenId;
        for (uint i = 0; i < amounts_; ++i) {
            level = _randomCardLevel();
            cardId = firstCardBag[level].cardId;
            tokenId = KTA.mint(_msgSender(), cardId);
            firstCardBag[level].amount = firstCardBag[level].amount.sub(1);
            emit OpenBox(_msgSender(), cardId, tokenId);
        }
        return true;
    }

    function secOpen(uint tokenId_, uint expireAt_, bytes32 r, bytes32 s, uint8 v) external openBoxStage returns (uint) {
        require(block.timestamp <= expireAt_, "Signature expired");
        uint cardId = KTA.cardIdMap(tokenId_);
        require(cardId == 50004 || cardId == 50005 || cardId == 50006 || cardId == 50007, "Invalid token id");

        bytes32 hash =  keccak256(abi.encodePacked(expireAt_, _msgSender()));
        address a = ecrecover(hash, v, r, s);
        require(a == banker, "Invalid signature");

        KTA.burn(tokenId_);

        if (secCardAmount <= 0) {
            return 0;
        }
        secCardAmount = secCardAmount.sub(1);

        uint level = _secRandomCardLevel();
        secCardBag[level].amount =  secCardBag[level].amount.sub(1);

        cardId = secCardBag[level].cardId;
        if (cardId == 0){
            emit OpenBox(_msgSender(), 0, 0);
            return 0;
        }

        uint tokenId = KTA.mint(_msgSender(), cardId);
        emit OpenBox(_msgSender(), cardId, tokenId);
        return tokenId;
    }

    function _randomCardLevel() internal returns (uint) {
        uint level = randomCeil(firstCardAmount);
        uint cardIndex;
        for (uint i = 0; i < firstCardBagCap; ++i){
            cardIndex = cardIndex.add(firstCardBag[i].amount);
            if (level <= cardIndex) {
                return i;
            }
        }

        revert("Random: Internal error");
    }

    function _secRandomCardLevel() internal returns (uint) {
        uint level = randomCeil(secCardAmount);
        uint cardIndex;
        for (uint i = 0; i < secCardBagCap; ++i){
            cardIndex = cardIndex.add(secCardBag[i].amount);
            if (level <= cardIndex) {
                return i;
            }
        }

        revert("Second random: Internal error");
    }

}