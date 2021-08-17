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
import "../interface/Ikaka721.sol";
import "../interface/Imsbox1155.sol";

contract MysteryBoxS1 is RandomGenerator, Context {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Address for address;
    using Strings for uint256;


    address public owner;

    // 售卖时间
    uint public saleStartTime;

    // 售卖和开盲盒的状态
    bool public isSale;
    bool public isOpenBox;

    // 价格
    uint public price;

    // 卡包
    mapping(uint => cardBagInfo) public cardBag;

    struct cardBagInfo {
        uint cardId;
        uint amount;
    }

    uint public cardBagCap;

    // 盲盒key 盲盒地址和盲盒对象
    uint public msBoxKey = 1;
    Imsbox public Msbox;

    // 收钱地址
    address public wallet;

    // USDT payment currency
    IERC20 public U;

    // 721 卡卡酱
    IKTA public KTA;

    // 卖出的盲盒数量和盲盒总量
    uint public saleBoxAmount;

    // 当前卡包内卡片数量
    uint public curCardAmount;

    uint public firSaleMaxNum;
    uint public secSaleMaxNum;
    uint public thiSaleMaxNum;

    // accumulated sales in number and USDT, accessable to the owner only
    uint private _accSales_n;
    uint private _accSales_u;


    event BuyBox(address indexed user, uint cardId, uint amount);
    event OpenBox721(address indexed user, uint indexed cardId, uint indexed tokenId);
    event OpenBox1155(address indexed user, uint indexed cardId);


    modifier onlyOwner () {
        require(_msgSender() == owner, "not owner's calling");
        _;
    }

    modifier saleStage () {
        require(isSale, "not sale stage");
        _;
    }

    modifier openBoxStage () {
        require(isOpenBox, "not openbox stage");
        _;
    }



    constructor(address KTA_, address Msbox_, address U_, address wallet_) {
        owner = _msgSender();
        // 卡卡酱
        KTA = IKTA(KTA_);
        // 盲盒合约
        Msbox = Imsbox(Msbox_);
        // usdt 地址
        U = IERC20(U_);
        // 收钱地址
        wallet = wallet_;


        // 价格
        price = 50 ether;

        // 盲盒内卡牌种类和数量
        uint[6] memory cardIds_ = [uint(2050001), uint(2050002), uint(2050003), uint(2050004), uint(2050005), uint(2)];
        uint[6] memory amounts_ = [uint(172), uint(114), uint(86), uint(42), uint(16), uint(2870)];
        cardBagCap = cardIds_.length;

        // 每天最大的发行量
        firSaleMaxNum = 800;
        secSaleMaxNum = 2300;
        thiSaleMaxNum = 3300;


        for (uint i = 0; i < cardBagCap; ++i) {
            cardBag[i] = cardBagInfo({
                cardId : cardIds_[i],
                amount : amounts_[i]
            });
            curCardAmount = curCardAmount.add(amounts_[i]);
        }
    }


    // **                          onlyOwner                           **//
    function transferOwnership(address com) public onlyOwner {
        owner = com;
    }

    // 更改售卖代币地址
    function setSaleToken(address com) public onlyOwner {
        U = IERC20(com);
    }

    // 更改收钱地址
    function setWallet(address com) public onlyOwner {
        wallet = com;
    }

    // 更改721地址
    function setKTAAddr(address com) public onlyOwner {
        KTA = IKTA(com);
    }

    // 更改盲盒地址
    function setMsboxAddr(address com) public onlyOwner {
        Msbox = Imsbox(com);
    }

    // 开启售卖阶段
    function startSale() external onlyOwner {
        require(!isSale);
        saleStartTime = block.timestamp;
        isSale = true;
    }

    // 停止售卖阶段
    function stopSale() external onlyOwner saleStage {
        isSale = false;
    }

    // 开启开盒子阶段
    function startOpenBox() external onlyOwner {
        require(!isOpenBox);
        isOpenBox = true;
    }

    // 关闭开盒子阶段
    function stopOpenBox() external onlyOwner openBoxStage {
        isOpenBox = false;
    }


    // 查看卖出情况
    function viewSales() external view onlyOwner returns (uint n, uint u) {
        return (_accSales_n, _accSales_u);
    }
    // **                          onlyOwner end                      **//



    // 购买盲盒，返回用户拥有的盲盒数量
    function buyBox(uint amounts_) external saleStage returns (bool) {
        // 卖出数量不能超过发行总量
        uint curSaleBox = saleBoxAmount.add(amounts_);
        // 判断时间
        require(block.timestamp >= saleStartTime);
        uint tm = (block.timestamp).sub(saleStartTime);
        // 判断每天的发行量
        if (tm <= 1 days) {
            require(curSaleBox <= firSaleMaxNum, "Out of limit");
        } else if (tm <= 2 days) {
            require(curSaleBox <= secSaleMaxNum, "Out of limit");
        } else if (tm <= 3 days) {
            require(curSaleBox <= thiSaleMaxNum, "Out of limit");
        } else {
            revert("Has ended");
        }

        // 转账
        U.safeTransferFrom(_msgSender(), wallet, amounts_.mul(price));

        // 生成盲盒
        Msbox.mint(_msgSender(), msBoxKey, amounts_);

        // 记录当前卖出盲盒数量和USDT
        saleBoxAmount = curSaleBox;
        _accSales_n += amounts_;
        _accSales_u += amounts_.mul(price);

        emit BuyBox(_msgSender(), msBoxKey, amounts_);
        return true;
    }

    // 开启盲盒， 返回tokenid (1155固定为2)
    function openBox() external openBoxStage returns (uint) {
        // 判断卡包内卡牌数量
        require(curCardAmount >= 1, "Out of limit");

        // 销毁盲盒
        Msbox.burn(_msgSender(), msBoxKey, 1);

        // 记录卡包内剩余卡牌数量
        curCardAmount = curCardAmount.sub(1);

        uint tokenId;

        uint level = _randomLevel();
        uint cardId = cardBag[level].cardId;
        if (level == cardBagCap-1) {
            tokenId = cardId;
            Msbox.mint(_msgSender(), cardId, 1);
            emit OpenBox1155(_msgSender(), cardId);
        } else {
            tokenId = KTA.mint(_msgSender(), cardId);
            emit OpenBox721(_msgSender(), cardId, tokenId);
        }

        cardBag[level].amount = cardBag[level].amount.sub(1);

        return tokenId;
    }


    // 开启盲盒
    function openBoxBatch(uint amounts_) external openBoxStage returns (bool) {
        // 判断卡包内卡牌数量
        require(curCardAmount >= amounts_, "Out of limit");

        // 销毁盲盒
        Msbox.burn(_msgSender(), msBoxKey, amounts_);

        // 记录卡包内剩余卡牌数量
        curCardAmount = curCardAmount.sub(amounts_);

        uint level;
        uint cardId;
        uint tokenId;
        for (uint i = 0; i < amounts_; ++i) {
            level = _randomLevel();
            cardId = cardBag[level].cardId;
            if (level == cardBagCap - 1) {
                Msbox.mint(_msgSender(), cardId, 1);
                emit OpenBox1155(_msgSender(), cardId);
            } else {
                tokenId = KTA.mint(_msgSender(), cardId);
                emit OpenBox721(_msgSender(), cardId, tokenId);
            }
            // 卡包内对应数量的牌减一
            cardBag[level].amount = cardBag[level].amount.sub(1);
        }
        return true;
    }


    // 产生一个还存在卡牌的level
    function _randomLevel() internal returns (uint) {
        uint level = randomCeil(curCardAmount);
        uint cardIndex;
        for (uint i = 0; i < cardBagCap; ++i) {
            cardIndex = cardIndex.add(cardBag[i].amount);
            if (level <= cardIndex) {
                return i;
            }
        }
        revert("Random: Internal error");
    }
}
