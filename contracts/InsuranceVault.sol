//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "./IDepos.sol";
import "./Interface/ERC20Helper.sol";
import "./Interface/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOracle.sol";
import "./IAssetManager.sol";
import "./AMOs/IAMOManager.sol";
import "./Mock/IMockSwap.sol";

contract InsuranceVault is ERC20Helper, Ownable {
    address public pool_address;
    address public depos_address;

    address public amo_manager_address;
    address public asset_manager_address;

    address private swap_address;
    
    // price oracle
    address public oracle_address;
    uint256 constant PRICE_PRECISION = 1e6;

    // supported stablecoins
    address[] public supported_stablecoins;
    mapping(address => bool) public is_stablecoin; // for quick varification

    constructor(
        address _depos_address,
        address _oracle_address,
        address _asset_manager_address,
        address _amo_manager_address,
        address _swap_address
    ) {
        require((_depos_address != address(0)) && (_oracle_address != address(0)) && (_asset_manager_address != address(0)) && (_amo_manager_address != address(0)), "Zero address detected");
        depos_address = _depos_address;
        oracle_address = _oracle_address;
        asset_manager_address = _asset_manager_address;
        amo_manager_address = _amo_manager_address;
        swap_address = _swap_address;
    }

    /****** MODIFIER ******/
    modifier onlyPool() {
        require(msg.sender == pool_address, "You are not pool");
        _;
    }

    modifier onlyValidAsset(address asset_address) {
        require(IAssetManager(asset_manager_address).assetAvailable(asset_address) == true, "Asset not available");
        _;
    }

    modifier onlyAMOManager() {
        require(msg.sender == amo_manager_address, "You are not amo manager");
        _;
    }

    /****** RESTRICTED FUNCTIONS ******/
    function addSupportedStablecoin(address stablecoin_address) external onlyOwner {
        require(stablecoin_address != address(0), "Zero address detected");
        supported_stablecoins.push(stablecoin_address);
        is_stablecoin[stablecoin_address] = true;
    }

    function removeSupportedStablecoin(address stablecoin_address) external onlyOwner {
        require(stablecoin_address != address(0), "Zero address detected");
        bool flag = false;
        uint index = 0;
        for (uint i = 0; i < supported_stablecoins.length; i++) {
            if (stablecoin_address == supported_stablecoins[i]) {
                flag = true;
                index = i;
                break;
            }
        }
        if (flag) {
            supported_stablecoins[index] = supported_stablecoins[supported_stablecoins.length - 1];
            supported_stablecoins.pop();
            delete is_stablecoin[stablecoin_address];
        }
    }

    function setPoolAddress(address new_pool) external onlyOwner {
        require(new_pool != address(0), "Zero address detected");
        pool_address = new_pool;
    }

    function setAMOManagerAddress(address new_amo_manager) external onlyOwner {
        require(new_amo_manager != address(0), "Zero address detected");
        amo_manager_address = new_amo_manager;
    }

    function setOracleAddress(address new_oracle) external onlyOwner {
        require(new_oracle != address(0), "Zero address detected");
        oracle_address = new_oracle;
    }

    function setDeposAddress(address new_depos) external onlyOwner {
        require(new_depos != address(0), "Zero address detected");
        depos_address = new_depos;
    }

    function setAssetManagerAddress(address new_asset_manager) external onlyOwner {
        require(new_asset_manager != address(0), "Zero address detected");
        asset_manager_address = new_asset_manager;
    }

    function ExecuteCompensation(address user_address, uint256 amount_in_dollar) external onlyPool {
        uint256 amount_left = amount_in_dollar;
        for (uint i = 0; i < supported_stablecoins.length; i++) {
            IERC20 stablecoin = IERC20(supported_stablecoins[i]);
            uint256 decimals = stablecoin.decimals();
            uint256 balance = stablecoin.balanceOf(address(this));
            if ((uint256(10) ** decimals) * amount_left <= PRICE_PRECISION * balance) {
                TransferToken(supported_stablecoins[i], user_address, (uint256(10) ** decimals) * amount_left / PRICE_PRECISION);
                amount_left = 0;
                break;
            } else {
                uint256 new_amount_left = amount_left - balance * PRICE_PRECISION / (uint256(10) ** decimals);
                uint256 amount_to_transfer = (amount_left - new_amount_left) * (uint256(10) ** decimals) / PRICE_PRECISION;
                amount_left = new_amount_left;
                TransferToken(supported_stablecoins[i], user_address, amount_to_transfer);
            }
        }
        // TODO
        require(amount_left == 0);
    }

    function TransferAssetToDollar() external onlyAMOManager {
        IAssetManager asset_manager = IAssetManager(asset_manager_address);
        for (uint i = 0; i < asset_manager.getAssetArray().length; i++) {
            address asset_address = asset_manager.getAssetArray()[i];
            if (asset_address != address(0) && (is_stablecoin[asset_address] == false)) {
                uint256 asset_balance = IERC20(asset_address).balanceOf(address(this));
                TransferToken(asset_address, swap_address, asset_balance);
                IMockSwap(swap_address).swapAssetToSC(asset_address, asset_balance);
            }
        }
    }


    /******* PUBLIC FUNCTIONS *******/
    function AssetBalance(address asset_address) external view onlyValidAsset(asset_address) returns (uint256) {
        return IERC20(asset_address).balanceOf(address(this));
    }

    function AssetDollarBalance(address asset_address) external view onlyValidAsset(asset_address) returns (uint256) {
        // NOTE: currently returns 10**decimals view
        uint256 asset_balance = IERC20(asset_address).balanceOf(address(this));
        uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
        return asset_balance * asset_price / PRICE_PRECISION;
    }

    function VaultDollarBalance() external view returns (uint256) { // returns 1e6 view
        IAssetManager asset_manager = IAssetManager(asset_manager_address);
        uint256 dollar_balance = 0;
        for (uint i = 0; i < asset_manager.getAssetArray().length; i++) {
            address asset_address = asset_manager.getAssetArray()[i];
            if (asset_address != address(0)) {
                uint8 decimals = IERC20(asset_address).decimals();
                uint256 asset_balance = IERC20(asset_address).balanceOf(address(this));
                uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
                dollar_balance += asset_balance * asset_price / (10 ** decimals);
            }
        }
        return dollar_balance;
    }

}