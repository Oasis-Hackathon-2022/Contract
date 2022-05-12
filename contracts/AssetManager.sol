//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetManager is Ownable {
    address[] public asset_array;
    mapping(address => bool) public assets; // faster verification

    constructor() {

    }

    /******* RESTRICTED FUNCTIONS ********/

    function addAsset(address asset_address) external onlyOwner {
        require(asset_address != address(0), "Zero address detected");
        require(assets[asset_address] == false, "Asset already added");
        assets[asset_address] = true;
        asset_array.push(asset_address);
        emit AssetAdded(asset_address);
    }

    function removeAsset(address asset_address) external onlyOwner {
        require(asset_address != address(0), "Zero address detected");
        require(assets[asset_address] == true, "Address nonexistant");
        delete assets[asset_address];
        // 'Delete' from the array by setting the address to 0x0
        for (uint i = 0; i < asset_array.length; i++){ 
            if (asset_array[i] == asset_address) {
                asset_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
        emit AssetRemoved(asset_address);
    }

    /******* PUBLIC FUNCTIONS *******/
    function assetAvailable(address asset_address) external view returns(bool) {
        return assets[asset_address];
    }

    function getAssetArray() external view returns (address[] memory assets_) {
        assets_ = new address[](asset_array.length);
        for (uint i = 0; i < asset_array.length; i++) {
            assets_[i] = asset_array[i];
        }
    }
    
    /****** EVENTS ******/
    event AssetAdded(address asset_address);
    event AssetRemoved(address asset_address);
}