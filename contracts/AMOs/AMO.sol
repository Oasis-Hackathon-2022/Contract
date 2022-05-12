//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAMO.sol";
import "./IAMOManager.sol";
import "../Interface/ERC20Helper.sol";
import "../Interface/IERC20.sol";

contract AMO is Ownable, ERC20Helper {
    address public amo_manager_address;
    
    
    // NOTE: after constructor we need to add the address to AMO Manager
    constructor(
        address _amo_manager_address
    ) {
        require(_amo_manager_address != address(0), "Zero address detected");
        amo_manager_address = _amo_manager_address;
    }

    /****** MODIFIERS ******/
    modifier onlyManager() {
        require(msg.sender == amo_manager_address, "You are not amo manager");
        _;
    }

    /****** RESTRICTED FUNCTIONS ******/
    function SetAMOManager(address _amo_manager_address) external onlyOwner {
        require(_amo_manager_address != address(0), "Zero address detected");
        amo_manager_address = _amo_manager_address;
    }
}