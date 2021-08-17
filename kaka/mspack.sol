// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/Ikaka1155.sol";

contract RandomGenerator {
    uint private randNonce = 0;

    function random(uint256 seed) internal returns (uint256) {
        randNonce += 1;
        return uint256(keccak256(abi.encodePacked(
                blockhash(block.number - 1),
                blockhash(block.number - 2),
                blockhash(block.number - 3),
                blockhash(block.number - 4),
                blockhash(block.number - 5),
                blockhash(block.number - 6),
                blockhash(block.number - 7),
                blockhash(block.number - 8),
                block.timestamp,
                msg.sender,
                randNonce,
                seed
            )));
    }

    function randomCeil(uint256 q) internal returns (uint256) {
        return (random(gasleft()) % q) + 1;
    }
}
contract MspackSale is Context {

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    bool public isStart;
    uint public startTime;
    uint constant price = 400;
    uint public period = 1 days;
    address public owner;
    address public Wallet = 0xaa9BC660C71cAfd9a74C636E7eC2086791Cc8A35;

    // accumulated sales in number and USDT, accessable to the owner only
    uint private accSales_n;
    uint private accSales_u;

    //discount rates 80 90 95
    uint[3] public discount;
    //quota for each discount level, constant
    uint[3] public quota_discount;
    // 20 collaborative franchised
    mapping(bytes32 => bool) public isFranchise;

    bytes32[35] private referalCode;

    uint public maxPackAmount;
    uint public maxPersonAmount;
    uint[3] private sales_first3days; // record sales quantity on first 3 days

    //USDT payment currency
    address public token;
    uint decimal = 1 ether;

    struct Ledger {
        uint total; // in counts
        uint value; // in money
    }

    struct Ledger2 {
        uint total;
        uint value;
        //uint[3] QatDiscount; // quantity sales at each discount level
    }


    mapping(bytes32 => Ledger2) public Franchise;

    mapping(address => Ledger) public userInfo;

    event Purchase(address indexed buyer, bytes32 indexed referal, uint256 price, uint256 amount);


    constructor(address _saleToken, address _Wallet) {
        token = _saleToken;
        Wallet = _Wallet;

        owner = _msgSender();
        maxPackAmount = 10000;
        maxPersonAmount = 50;

        discount[0] = 80;
        discount[1] = 90;
        discount[2] = 95;

        // quota at each discount for all franchses
        quota_discount[0] = 700;
        quota_discount[1] = 1750;
        quota_discount[2] = 3150;
    }

    modifier onlyOwner{
        require(owner ==_msgSender(), "only owner");
        _;
    }


    function start(uint time) external onlyOwner {
        require(!isStart);
        require(startTime == 0);
        isStart = true;
        startTime = time;
    }


    function stop() external onlyOwner {
        isStart = false;
    }

    function setReferalCode(bytes32[35] memory codes) external onlyOwner {
        require(!isStart, "must set before it started!!!");
        for (uint i = 0; i < 35; i++) {
            referalCode[i] = codes[i];
            isFranchise[referalCode[i]] = true;
        }
    }


    /**
     * get sales at each discount level for the first 3 days
    */
    function getter(uint day) external view returns (uint){
        require(day<3,"wrong day");
        return sales_first3days[day];
    }


    function purchase(bytes32 referal, uint amount) internal returns (bool) {
        require(isStart, "Activity not started yet!!");
        require(isFranchise[referal], "invalid referal code!!!");
        require(accSales_n < maxPackAmount, 'total quota depleted');

        // individual limit
        require(userInfo[_msgSender()].total < maxPersonAmount, "one address can purchase up to 50 boxes");
        require(amount <= 10, "Sorry, cannot purchase more than 10 boxes each time!");

        // quota available total and individually. compare three remaining quota.
        uint quotaRemains1 = maxPackAmount.sub(accSales_n);
        uint quotaRemains2 = maxPersonAmount.sub(userInfo[_msgSender()].total);
        uint maxAmount = quotaRemains2 > quotaRemains1 ? quotaRemains1 : quotaRemains2;

        // actual amount the customer can buy, notify the customer the remaining quota!
        uint _amount = amount >= maxAmount ? maxAmount : amount;

        // determine actual price
        uint _price = price;
        uint d = (block.timestamp - startTime).div(period);

        if (d < 3) {
            _price = discount[d].mul(_price).div(100);
            require(sales_first3days[d] < quota_discount[d], 'daily quota at this discount has been depleted');
            uint temp = quota_discount[d].sub(sales_first3days[d]);
            _amount = _amount > temp ? temp : _amount;

            IERC20(token).safeTransferFrom(_msgSender(), Wallet, _amount.mul(_price) * decimal);

            sales_first3days[d] += _amount;
        } else {
            // transfer to mutual community simultaneously, revenue over 320 will be sent to owners
            IERC20(token).safeTransferFrom(_msgSender(), Wallet, _amount.mul(_price) * decimal);
        }

        // update accumulated sales value and amounts
        accSales_n += _amount;
        accSales_u += _amount.mul(_price);
        // update for each Franchise
        Franchise[referal].total += _amount;
        Franchise[referal].value += _amount.mul(_price);
        // update individually
        userInfo[_msgSender()].total += _amount;
        userInfo[_msgSender()].value += _amount.mul(_price);

        emit Purchase(_msgSender(), referal, _price, _amount);
        return true;
    }

    function TransferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function Withdraw(address account) public onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(account, balance);
    }
    /*
    * view accumulated total sales quantity and usdt value
    */
    function viewSales() external view returns (uint n, uint u){
        n = accSales_n;
        u = accSales_u;
    }

    /*
    * get real time price, determined by date
    */
    function realtimePrice() external view returns (uint realPrice){
        uint d = (block.timestamp - startTime).div(period);
        realPrice = d < 3 ? discount[d].mul(price).div(100) : price;
    }

}

contract Mspack721 is Context, ERC721Enumerable {
    string baseURI;
    constructor(string memory name_, string memory symbol_, string memory myBaseURI_) ERC721(name_, symbol_) {
    }
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}

contract Mspack is RandomGenerator, Context, MspackSale, Mspack721 {
    using SafeMath for uint;

    using Counters for Counters.Counter;
    Counters.Counter private _packIds;
    IKTN KTN;
    mapping(uint => uint) levelLimit;

    event OpenPack(address user, uint[] totalKinds, uint[] totalAmounts);

    constructor (address KTNAddr, address saleToken_, address Wallet_, string memory name_, string memory symbol_, string memory myBaseURI_) Mspack721(name_, symbol_, myBaseURI_) MspackSale(saleToken_, Wallet_) {
        KTN = IKTN(KTNAddr);
        levelLimit[1] = 320;
        levelLimit[2] = 280;
        levelLimit[3] = 89;
        levelLimit[4] = 18;
        levelLimit[5] = 7;
    }

    function buyPack(bytes32 referal_, uint amount_) external {
        bool ok = purchase(referal_, amount_);
        require(ok, "purchasing error");

        for (uint i = 0; i < amount_; ++i) {
            _packIds.increment();
            uint packId = _packIds.current();
            _mint(_msgSender(), packId);
        }
    }

    function openPack(uint packId_) external {
        address user = _msgSender();

        require(_isApprovedOrOwner(_msgSender(), packId_), "ERC721: burn caller is not owner nor approved");
        _burn(packId_);
        // for each level loop
        uint[] memory totalKinds = new uint[](25);
        uint[] memory totalAmounts = new uint[](25);
        for (uint i = 0; i < 5; i++) {
            (uint[5] memory kinds, uint[5] memory amounts) = getCard(i + 1);
            for (uint j = 0; j < 5; j++)  {
                totalKinds[i * 5 + j] = kinds[j];
                totalAmounts[i * 5 + j] = amounts[j];
            }
        }

        KTN.mintBatch(user, totalKinds, totalAmounts);
        emit OpenPack(user, totalKinds, totalAmounts);
    }

    /*
    * reveal mystery box results, cardId and corresponding quantity
    */
    function getCard(uint _level) public returns (uint[5] memory, uint[5] memory) {
        uint quota = levelLimit[_level];
        require(quota != 0, "error level");
        // number of card kinds
        uint[5] memory kinds;
        uint[5] memory quantities;
        uint[5] memory ratio;
        uint ratioSum = 0;
        uint left = quota;

        // remove 10003 card id
        if(_level == 1){
            uint rdn;
            for (uint i = 0; i < kinds.length; i++)
            {

                rdn = randomCeil(10);
                rdn = rdn >= 3 ? rdn+1 : rdn;
                kinds[i] = rdn + 10000 + 11 * (_level - 1);

            }

        }

        else{
            for (uint i = 0; i < kinds.length; i++) {
                kinds[i] = randomCeil(11) + 10000 + 11 * (_level - 1);
            }
        }
        for (uint i = 0; i < quantities.length; i++) {
            ratio[i] = randomCeil(100_000_000);
            ratioSum += ratio[i];
        }
        for (uint i = 0; i < quantities.length; i++) {
            quantities[i] = quota.mul(ratio[i]).div(ratioSum);
            left = left.sub(quantities[i]);
        }
        quantities[0] = quantities[0].add(left);
        return (kinds, quantities);
    }
}
