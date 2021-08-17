// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../other/random_generator.sol";
import "../interface/Ikaka721.sol";


contract MysteryBoxS3 is RandomGenerator, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Address for address;


    // USDT
    IERC20 public U;
    // 721
    IKTA public KTA;
    // 价格
    uint public price;
    // USDT回购资金
    uint public backU;
    // 开始时间
    uint public startTime;

    // 是否开启的状态
    bool public isStart;
    address public banker;



    Winner public winner;
    struct Winner {
        address addr;
        uint opentTime;
        uint duration;
        bool isWin;
    }

    // // 中奖地址
    // bool public isWin;
    // address public winner;
    // uint public duration;


    // 卡包
    uint public cardBagCap;
    uint public totalCard;
    uint public curCardAmount;
    mapping(uint => cardBagInfo) public cardBag;
    struct cardBagInfo {
        uint cardId;
        uint amount;
    }

    event OpenBox(address indexed user, uint indexed cardId, uint indexed tokenId);

    modifier startStage () {
        require(isStart, "Unopened");
        _;
    }

    constructor() {
        // 721
        KTA = IKTA(0x3565AC59Aa2127D4C45bd050b673fBe6202cd742);
        // usdt
        U = IERC20(0x55d398326f99059fF775485246999027B3197955);
        // banker
        banker = 0x7277cBfAB55Cdb9638B91dEb21d1BD2eEb7E7717;
        // 价格
        price = 88 ether;
        price = price.mul(48).div(100);

        uint[6] memory cardIds_ = [uint(70021), uint(70022), uint(70023), uint(70024), uint(1), uint(0)];
        uint[6] memory amounts_ = [uint(58), uint(173), uint(287), uint(460), uint(3157), uint(1608)];
        cardBagCap = cardIds_.length;

        for (uint i = 0; i < cardBagCap; i++) {
            cardBag[i] = cardBagInfo({
                cardId : cardIds_[i],
                amount : amounts_[i]
            });
            curCardAmount = curCardAmount.add(amounts_[i]);
        }
        totalCard = curCardAmount;
    }


    /* —————————————————————————————————————————————————————————— onlyOwner —————————————————————————————————————————————————————————— */
    // 更改售卖代币地址
    function setSaleToken(address com) public onlyOwner {
        U = IERC20(com);
    }
    // 更改721地址
    function setKTAAddr(address com) public onlyOwner {
        KTA = IKTA(com);
    }
    // 设置banker地址
    function setBanker(address com) external onlyOwner {
        banker = com;
    }
    // 设置价格
    function setPrice(uint price_) external onlyOwner {
        price = price_;
    }
    // 开启
    function start() external onlyOwner {
        require(!isStart, "running");
        isStart = true;
        startTime = block.timestamp;
    }
    // 提卡
    function setApprovalForAll(address account_) public onlyOwner {
        KTA.setApprovalForAll(account_, true);
    }
    // 提钱
    function safePull(address account_, uint amount_) public onlyOwner {
        U.safeTransfer(account_, amount_);
    }
    // 关闭
    function stop() external onlyOwner startStage {
        isStart = false;
    }
    /* —————————————————————————————————————————————————————————— onlyOwner end —————————————————————————————————————————————————————————— */

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

    function _chechWinner() internal {
        if (winner.isWin) {
            return;
        }

        // 第一个入场的人初始化
        if (curCardAmount == totalCard) {  
            winner.addr = _msgSender();
            winner.opentTime = block.timestamp;
            winner.duration = 0;
            winner.isWin = false;
            return;
        }

        // 处理winner
        uint duration = (block.timestamp).sub(winner.opentTime);
        if (duration  >= 1 days) {
            winner.isWin = true;
            winner.duration = duration;
        } else {
            // 同一用户连续开盲盒不会刷新倒计时
            if (winner.addr == _msgSender()) {
                return;
            }
            winner.addr = _msgSender();
            winner.opentTime = block.timestamp;
        }
    }

    function openBox(uint tokenId_, uint expireAt_, bytes32 r, bytes32 s, uint8 v) external startStage returns (uint) {
        require(block.timestamp <= expireAt_, "Signature expired");
        require(block.timestamp >= startTime);
        
        // 校验签名
        bytes32 hash =  keccak256(abi.encodePacked(expireAt_, _msgSender()));
        address a = ecrecover(hash, v, r, s);
        require(a == banker, "Invalid signature");
        
        // 校验cardId
        uint cardId = KTA.cardIdMap(tokenId_);
        require(cardId >= 70005 && cardId <= 70020, "Invalid token id");

        // 判断卡包内卡牌数量
        require(curCardAmount > 0, "Out of limit");

        // 处理winner
        _chechWinner();

        // 销毁传入卡牌
        KTA.burn(tokenId_);
        
        uint level = _randomLevel();
        cardId = cardBag[level].cardId;
        // 卡包内对应数量的牌减一
        cardBag[level].amount = cardBag[level].amount.sub(1);
        // 记录卡包内剩余卡牌数量
        curCardAmount = curCardAmount.sub(1);
        
        // 28%的概率啥都没得到
        if (cardId == 0) {
            emit OpenBox(_msgSender(), 1, 0);
            return 1;
        }

        if (cardId == 1) {
            U.transfer(_msgSender(), price);
            backU += price;
            emit OpenBox(_msgSender(), 0, 0);
            return 0;
        }
    
        // mint新的卡牌给用户
        uint tokenId = KTA.mint(_msgSender(), cardId);

        emit OpenBox(_msgSender(), cardId, tokenId); 
        return tokenId;
    }
}
