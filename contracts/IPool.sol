// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

interface IPool {
    function GiveAMOAsset(address asset_address, uint256 asset_amount) external;
    function transferTicketOwner(uint _tokenId,address newOwner) external;
    function recordTransferProfitFromAMO(address asset, uint assetAmount) external;
}