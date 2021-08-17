// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/Ikaka1155.sol";
import "../interface/Ikaka721.sol";

contract NormalSaleBase {

    address public owner;
    address public wallet;
    IERC20 public U;
    bool public isOpen;

    mapping(uint => uint) public price;
    mapping(uint => uint) public inventory;
    mapping(uint => bool) public status;

    event Purchase(address indexed buyer, uint[] ids, uint[] amounts, uint uAmounts);

    function _msgSender() internal view returns (address){
        return msg.sender;
    }

    constructor(address saleToken_, address wallet_){
        owner = _msgSender();
        U = IERC20(saleToken_);
        wallet = wallet_;
    }

    modifier onlyOwner{
        require(msg.sender == owner, "only owner!");
        _;
    }

    // -------------------- onlyOwner---------------- //
    function transferOwnership(address newowner_) public onlyOwner returns (bool) {
        owner = newowner_;
        return true;
    }

    function setIsOpen(bool isOpen_) public onlyOwner returns (bool) {
        isOpen = isOpen_;
        return true;
    }

    function setU(address U_) public onlyOwner returns (bool) {
        U = IERC20(U_);
        return true;
    }

    function setGoods(uint[] calldata ids_, uint[] calldata price_, uint[] calldata inventory_) public onlyOwner returns (bool) {
        require(ids_.length > 0, "wrong length");
        require(ids_.length == price_.length && ids_.length == inventory_.length, "diffrent length");
        for (uint i = 0; i < ids_.length; i++) {
            price[ids_[i]] = price_[i];
            inventory[ids_[i]] = inventory_[i];
        }
        return true;
    }

    function setStatus(uint[] calldata ids_, bool[] calldata status_) public onlyOwner returns (bool) {
        require(ids_.length > 0, "wrong length");
        require(ids_.length == status_.length, "diffrent length");
        for (uint i = 0; i < ids_.length; i++) {
            status[ids_[i]] = status_[i];
        }
        return true;
    }
    // -------------------- onlyOwner--end-------------- //

}

contract NormalSaleKTN is NormalSaleBase {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    IKTN public KTN;

    function setKAKACard(address KAKACard_) public onlyOwner returns (bool) {
        KTN = IKTN(KAKACard_);
        return true;
    }

    constructor(address KTN_, address saleToken_, address wallet_) NormalSaleBase(saleToken_, wallet_) {
        KTN = IKTN(KTN_);
    }

    function purchase(uint[] calldata ids_, uint[] calldata amounts_) external {
        require(isOpen, "not open");
        //check if ids are of level 1-5 and amounts not exceed quota
        require(ids_.length == amounts_.length, "lengths of ids and quantity should be equal");

        // notify the custormer the usdt amount needed
        uint uAmount;

        for (uint i = 0; i < ids_.length; i++) {
            require(status[ids_[i]], "Not Open");
            require(amounts_[i] > 0, "quantity should be positive");
            require(inventory[ids_[i]] >= amounts_[i], "Out Limit");
            inventory[ids_[i]] = inventory[ids_[i]].sub(amounts_[i]);

            uAmount = uAmount.add(price[ids_[i]].mul(amounts_[i]));
        }

        U.safeTransferFrom(_msgSender(), wallet, uAmount);

        KTN.mintBatch(_msgSender(), ids_, amounts_);

        emit Purchase(_msgSender(), ids_, amounts_, uAmount);
    }

}


contract NormalSaleKTA is NormalSaleBase {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    IKTA public KTA;

    function setKAKACard(address KAKACard_) public onlyOwner returns (bool) {
        KTA = IKTA(KAKACard_);
        return true;
    }

    constructor(address KTA_, address saleToken_, address wallet_) NormalSaleBase(saleToken_, wallet_) {
        KTA = IKTA(KTA_);
    }

    function purchase(uint[] calldata ids_, uint[] calldata amounts_) external {
        require(isOpen, "not open");
        //check if ids are of level 1-5 and amounts not exceed quota
        require(ids_.length == amounts_.length, "lengths of ids and quantity should be equal");

        // notify the custormer the usdt amount needed
        uint uAmount;

        for (uint i = 0; i < ids_.length; i++) {
            require(status[ids_[i]], "Not Open");
            require(amounts_[i] > 0, "quantity should be positive");
            require(inventory[ids_[i]] >= amounts_[i], "Out Limit");
            inventory[ids_[i]] = inventory[ids_[i]].sub(amounts_[i]);

            uAmount = uAmount.add(price[ids_[i]].mul(amounts_[i]));
        }

        U.safeTransferFrom(_msgSender(), wallet, uAmount);

        for (uint i = 0; i < ids_.length; i++) {
            KTA.mintMulti(_msgSender(), ids_[i], amounts_[i]);
        }

        emit Purchase(_msgSender(), ids_, amounts_, uAmount);

    }
}

contract NormalSaleMickey is NormalSaleBase, ERC721Holder {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    IKTA public KTA;
    event Withdraw(address to, uint value);

    constructor(address KTA_, address saleToken_, address wallet_) NormalSaleBase(saleToken_, wallet_) {
        KTA = IKTA(KTA_);
    }
    function withdraw(uint volume_,address payable wallet_) external onlyOwner {
        wallet_.transfer(volume_);
        emit Withdraw(wallet_, volume_);
    }
    function setKAKACard(address KAKACard_) public onlyOwner returns (bool) {
        KTA = IKTA(KAKACard_);
        return true;
    }
    function setApprovalForAll(address account_) public onlyOwner {
        KTA.setApprovalForAll(account_, true);
    }

    function purchase(uint[] calldata ids_, uint[] calldata amounts_) external payable {
        require(isOpen, "not open");
        //check if ids are of level 1-5 and amounts not exceed quota
        require(ids_.length == amounts_.length, "lengths of ids and quantity should be equal");

        // notify the custormer the usdt amount needed
        uint uAmount;

        for (uint i = 0; i < ids_.length; i++) {
            require(status[ids_[i]], "Not Open");
            require(amounts_[i] > 0, "quantity should be positive");
            require(inventory[ids_[i]] >= amounts_[i], "Out Limit");
            inventory[ids_[i]] = inventory[ids_[i]].sub(amounts_[i]);

            uAmount = uAmount.add(price[ids_[i]].mul(amounts_[i]));
        }

        require(msg.value >= uAmount,"erro value");

        for (uint i = 0; i < ids_.length; i++) {
            for (uint j = 0; j < amounts_[i]; j++) {
                uint id = KTA.tokenOfOwnerByIndex(address(this), 0);
                KTA.safeTransferFrom(address(this), _msgSender(), id);
            }
        }
        emit Purchase(_msgSender(), ids_, amounts_, uAmount);
    }
}