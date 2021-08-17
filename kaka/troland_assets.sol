// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface KTNContract is IERC1155 {
    function burn(address account, uint256 id, uint256 value) external;
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
}

contract TrolandAssets is Context, ERC1155Holder {
    using SafeMath for uint;

    address public KAKA;
    KTNContract private KTN;
    modifier onlyKAKA () {
        require(_msgSender() == KAKA, "not KAKA's calling");
        _;
    }
    function setKAKA(address newKAKA_) public onlyKAKA returns (bool) {
        KAKA = newKAKA_;

        return true;
    }

    constructor (address KAKA_, address KTN_) {
        KAKA = KAKA_;
        KTN = KTNContract(KTN_);
    }

    event Deposit(uint indexed depositId, address indexed player, uint indexed cardId, uint amount);
    event Withdraw(uint indexed withdrawId, address indexed player, uint indexed cardId, uint amount);
    event Burn(uint indexed cardId, uint amount);

    address public banker;
    address public coldWallet;
    mapping (uint => bool) withdrawed;
    modifier onlyBanker () {
        require(_msgSender() == KAKA || _msgSender() == banker, "not banker's calling");
        _;
    }
    function setBanker(address newBanker_) public onlyKAKA returns (bool) {
        banker = newBanker_;

        return true;
    }

    function setColdWallet(address newWallet_) public onlyKAKA returns (bool) {
        coldWallet = newWallet_;

        return true;
    }


    using Counters for Counters.Counter;
    Counters.Counter private _depositIds;

    function deposit(uint[] calldata cardIds_, uint[] calldata amounts_) public returns (bool) {
        KTN.safeBatchTransferFrom(_msgSender(), address(this), cardIds_, amounts_, "");
        for (uint256 i = 0; i < cardIds_.length; ++i) {
            _depositIds.increment();
            uint depositId = _depositIds.current();
            emit Deposit(depositId, _msgSender(), cardIds_[i], amounts_[i]);
        }

        return true;
    }

    function withdraw(uint[] calldata cardIds_, uint[] calldata amounts_, uint withdrawId_, bytes32 r, bytes32 s, uint8 v) public returns (bool) {
        require(!withdrawed[withdrawId_], "withdrawed id");
        withdrawed[withdrawId_] = true;

        bytes32 hash =  keccak256(abi.encodePacked(withdrawId_, _msgSender(), cardIds_, amounts_));
        address a = ecrecover(hash, v, r, s);
        require(a == banker, "Invalid signature");

        KTN.safeBatchTransferFrom(address(this), _msgSender(), cardIds_, amounts_, "");
        for (uint256 i = 0; i < cardIds_.length; ++i) {
            emit Withdraw(withdrawId_, _msgSender(), cardIds_[i], amounts_[i]);
        }

        return true;
    }

    function toColdWallet(uint[] calldata cardIds_, uint[] calldata amounts_) public onlyBanker returns (bool) {
        KTN.safeBatchTransferFrom(address(this), coldWallet, cardIds_, amounts_, "");

        return true;
    }

    function burn(uint[] calldata cardIds_, uint[] calldata amounts_) public onlyBanker returns (bool) {
        KTN.burnBatch(address(this), cardIds_, amounts_);

        return true;
    }
}