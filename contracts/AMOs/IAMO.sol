//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

interface IAMO {
    function getAvailableAssets() external view returns (address[] memory assets);
    function AssetBalance(address asset_address) external view returns (uint256);
    function ExecuteStrategy(address asset_address, uint256 asset_amount) external;
    function MintProfit(address asset_address) external returns (uint256);
    function WithdrawAsset(address asset_address, uint256 asset_amount) external;
}