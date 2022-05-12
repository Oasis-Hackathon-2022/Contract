//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Mock/IMockSwap.sol";

contract Oracle is Ownable {
    mapping(address => uint256) public priceMap;

    constructor() {

    }

    function setPrice(address asset, uint256 price) external onlyOwner {
        priceMap[asset] = price;
    }

    function getPrice(address asset) external view returns(uint256) {
        return priceMap[asset];
    }

    function getTWAP(address asset, uint256 time_period) external view returns(uint256) {
        return priceMap[asset];
    }
}