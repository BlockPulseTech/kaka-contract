// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Imsbox {
    function mint(address to_, uint boxId_, uint amount_) external returns (bool);
    function burn(address account, uint256 id, uint256 value) external;
}
