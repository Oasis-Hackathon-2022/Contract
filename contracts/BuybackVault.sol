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

contract BuybackVault is ERC20Helper, Ownable {
    address public pool_address;
    address public depos_address;

    address public amo_manager_address;
    address public asset_manager_address;
    
    // price oracle
    address public oracle_address;
    uint256 constant PRICE_PRECISION = 1e6;

    // buyback bonus
    uint256 buyback_bonus;


    constructor(
        address _depos_address,
        address _oracle_address,
        address _asset_manager_address,
        address _amo_manager_address
    ) {
        require((_depos_address != address(0)) && (_oracle_address != address(0)) && (_asset_manager_address != address(0)) && (_amo_manager_address != address(0)), "Zero address detected");
        depos_address = _depos_address;
        oracle_address = _oracle_address;
        asset_manager_address = _asset_manager_address;
        amo_manager_address = _amo_manager_address;
        buyback_bonus = 50000;
    }

    /****** MODIFIER ******/
    modifier onlyPool() {
        require(msg.sender == pool_address, "You are not the pool");
        _;
    }

    modifier onlyValidAsset(address asset_address) {
        require(IAssetManager(asset_manager_address).assetAvailable(asset_address) == true, "Asset not available");
        _;
    }

    /****** RESTRICTED FUNCTIONS ******/
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

    function setBuybackBonus(uint256 new_buyback_bonus) external onlyOwner {
        require(new_buyback_bonus < PRICE_PRECISION, "Bonus cannot exceed 100%");
        buyback_bonus = new_buyback_bonus;
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

    function buybackDepos(uint256 depos_amount, address asset_address) external onlyValidAsset(asset_address) {        
        // burn depos token
        IDepos(depos_address).pool_burn_from(msg.sender, depos_amount);

        uint256 depos_price = IOracle(oracle_address).getPrice(depos_address);
        uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
        // e18 view, check
        uint256 asset_amount = depos_amount * depos_price * (PRICE_PRECISION + buyback_bonus) / PRICE_PRECISION / asset_price;
        require(asset_amount <= IERC20(asset_address).balanceOf(address(this)), "Not enough balance of required token in buyback vault");
        TransferToken(asset_address, msg.sender, asset_amount);
    }
}