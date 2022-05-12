//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "../AMO.sol";
import "../../Interface/IERC20.sol";
import "../../Mock/IMockERC20.sol";

contract Example_AMO is AMO {
    // TODO: add available assets
    address[] public available_assets;
    uint256 constant public PRICE_PRECISION = 1e6;

    uint256 constant private APY_PRECISION = 1e18;
    uint256 private sec_yield_rate;
    uint256 private last_mint_timestamp;
    uint256 private total_profit;

    constructor(
        address _amo_manager_address,
        address _asset // single asset as an example
    ) AMO(_amo_manager_address) {
        available_assets.push(_asset);
        last_mint_timestamp = block.timestamp;
        sec_yield_rate = uint256(2219685438);
        total_profit = 0;
    }

    /****** MODIFIERS ******/
    modifier AssetAvailable(address asset_address) {
        require(asset_address != address(0), "Zero address detected");
        bool flag = false;
        for (uint i = 0; i < available_assets.length; i++) {
            if (asset_address == available_assets[i]) {
                flag = true;
                break;
            }
        }
        require(flag, "Asset not available in this AMO");
        _;
    }

    /****** RESTRICTED FUNCTION ******/
    function MintProfit(address asset_address) external onlyManager returns (uint256 profit_mint) {
        // NOTE: in this example we just put the profit within it
        TransferToken(asset_address, amo_manager_address, total_profit);
        profit_mint = total_profit;
        total_profit = 0;
    }

    function ExecuteStrategy(address asset_address, uint256 asset_amount) external onlyManager AssetAvailable(asset_address) {
        require(IMockERC20(asset_address).balanceOf(address(this)) >= asset_amount, "Not enough balance");
        // TODO: deposit the asset, amount into the corresponding strategy
        // NOTE: in this example we just mint token
        uint256 amount_to_yield = IMockERC20(asset_address).balanceOf(address(this)) - total_profit - asset_amount;
        uint256 new_yield = (block.timestamp - last_mint_timestamp) * sec_yield_rate * amount_to_yield / APY_PRECISION;
        IMockERC20(asset_address).mint_to_example_amo(new_yield, address(this));
        total_profit += new_yield;
        last_mint_timestamp = block.timestamp;
    }

    function WithdrawAsset(address asset_address, uint256 asset_amount) external onlyManager AssetAvailable(asset_address) {
        require(asset_amount + total_profit <= IERC20(asset_address).balanceOf(address(this)), "Not enough balance");
        // TODO: withdraw
        // NOTE: in this example, we just transfer asset directly
        TransferToken(asset_address, amo_manager_address, asset_amount);
    }

    function UpdateAvailableAsset(address asset_address, uint256 transfer_in_amount) external onlyManager AssetAvailable(asset_address) {

    }

    /****** PUBLIC FUNCTIONS ******/
    function AssetBalance(address asset_address) external view AssetAvailable(asset_address) returns (uint256) {
        // TODO: return asset balance, including the one in the strategy
        // NOTE: in this example, we just automatically mint mock token
        return IERC20(asset_address).balanceOf(address(this)) - total_profit;
    }

    function getAvailableAssets() external view returns (address[] memory assets) {
        assets = new address[](available_assets.length);
        for (uint i = 0; i <available_assets.length; i++) {
            assets[i] = available_assets[i];
        }
    }
}