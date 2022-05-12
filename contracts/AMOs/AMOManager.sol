//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 


import "./AMO.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interface/ERC20Helper.sol";
import "../Interface/IERC20.sol";
import "../IAssetManager.sol";
import "../IOracle.sol";
import "../IPool.sol";
import "../IInsuranceVault.sol";




contract AMOManager is Ownable, ERC20Helper {
    address[] public amo_array;
    mapping(address => bool) public amos; // faster_verification
    mapping(address => bool) private amo_locked;

    address public pool_address;
    address public insurance_vault_address;
    address public buyback_vault_address;
    address public asset_manager_address;
    address public oracle_address;

    uint256 public last_mint_timestamp; // set to 0 on genesis
    uint256 public mint_interval; // set to 80000 on genesis

    uint256 constant public PRICE_PRECISION = 1e6; 
    uint256 public ratio_to_buyback; // set to 20000 on genesis
    uint256 public ratio_to_insurance; // set to 30000 on genesis

    // struct amo_info { // used to keep track of amo quota
    //     address amo_address;
    //     uint256 vote_number;
    // }

    mapping(address => address[]) public asset_available_amo_array;

    function AddAssetAmo(address asset_address, address amo_address) external onlyOwner {
        asset_available_amo_array[asset_address].push(amo_address);
    }

    constructor(
        address _asset_manager_address,
        address _oracle_address
    ) {
        require((_asset_manager_address != address(0) && (_oracle_address != address(0))), "Zero address detected");
        asset_manager_address = _asset_manager_address;
        oracle_address = _oracle_address;
        last_mint_timestamp = 0;
        mint_interval = 80000;
        ratio_to_buyback = 200000;
        ratio_to_insurance = 400000;
    }


    /****** MODIFIERS ******/
    modifier onlyPool() {
        require(msg.sender == pool_address, "You are not the pool");
        _;
    }

    modifier NewAMOValid(address amo_address) {
        require(amo_address != address(0), "Zero address detected");
        require(amos[amo_address] == false, "Address already exists");
        _;
    }

    modifier ValidAMO(address amo_address) {
        require(amos[amo_address] == true, "AMO non-existant");
        _;
    }

    modifier onlyValidAsset(address asset_address) {
        require(IAssetManager(asset_manager_address).assetAvailable(asset_address) == true, "Asset not available");
        _;
    }

    /****** RESTRICTED FUNCTIONS ******/
    function AddAMO(address amo_address) external onlyOwner NewAMOValid(amo_address) {
        // TODO: check if the amo exists
        amo_array.push(amo_address);
        amos[amo_address] = true;
    }

    function RemoveAMO(address amo_address) external onlyOwner ValidAMO(amo_address) {
        // 'Delete' from the array by setting the address to 0x0
        for (uint i = 0; i < amo_array.length; i++) { 
            if (amo_array[i] == amo_address) {
                amo_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
        delete amos[amo_address];
    }

    function setMintInterval(uint256 new_mint_interval) external onlyOwner {
        mint_interval = new_mint_interval;
    }

    function setPoolAddress(address new_pool) external onlyOwner {
        require(new_pool != address(0), "Zero address detected");
        pool_address = new_pool;
    }

    function setOracleAddress(address new_oracle) external onlyOwner {
        require(new_oracle != address(0), "Zero address detected");
        oracle_address = new_oracle;
    }

    function setBuybackVaultAddress(address new_buyback_vault) external onlyOwner {
        require(new_buyback_vault != address(0), "Zero address detected");
        buyback_vault_address = new_buyback_vault;
    }

    function setInsuranceVaultAddress(address new_insurance_vault) external onlyOwner {
        require(new_insurance_vault != address(0), "Zero address detected");
        insurance_vault_address = new_insurance_vault;
    }

    function setAssetManagerAddress(address new_asset_manager) external onlyOwner {
        require(new_asset_manager != address(0), "Zero address detected");
        asset_manager_address = new_asset_manager;
    }

    function setAssetDistributionRatio(uint256 new_ratio_to_buyback, uint256 new_ratio_to_insurance) external onlyOwner {
        require(new_ratio_to_buyback + new_ratio_to_insurance < PRICE_PRECISION, "Invalid new ratios");
        ratio_to_buyback = new_ratio_to_buyback;
        ratio_to_insurance = new_ratio_to_insurance;
    }

    function CollectProfitFromAMO(address amo_address) internal ValidAMO(amo_address) {
        IAMO amo = IAMO(amo_address);
        for (uint i = 0; i < amo.getAvailableAssets().length; i++) {
            address asset_address = amo.getAvailableAssets()[i];
            // NOTE: we do not calculate decimals here
            uint256 collected_asset_amount = amo.MintProfit(asset_address);
            uint256 asset_to_buyback = collected_asset_amount * ratio_to_buyback / PRICE_PRECISION;
            uint256 asset_to_insurance = collected_asset_amount * ratio_to_insurance / PRICE_PRECISION;
            TransferToken(asset_address, buyback_vault_address, asset_to_buyback);
            TransferToken(asset_address, insurance_vault_address, asset_to_insurance);
            uint profitAmount = collected_asset_amount - asset_to_buyback - asset_to_insurance;
            TransferToken(asset_address, pool_address, profitAmount);
            IPool(pool_address).recordTransferProfitFromAMO(asset_address, profitAmount);
        }
        IInsuranceVault(insurance_vault_address).TransferAssetToDollar();
    }

    // manually give asset to an amo
    function GiveAssetToAMO(address asset_address, address amo_address, uint256 asset_amount) external onlyOwner onlyValidAsset(asset_address) ValidAMO(amo_address) {
        // NOTE: Pool contract has modifier onlyAMOManager
        IPool(pool_address).GiveAMOAsset(asset_address, asset_amount);

        TransferToken(asset_address, amo_address, asset_amount);

        // NOTE: AMO contract has modifier onlyAMOManager
        IAMO(amo_address).ExecuteStrategy(asset_address, asset_amount);
    }

    // automatically withdraw asset from valid amos
    function WithdrawAssetFromAMO(address asset_address, uint256 asset_amount) external onlyPool onlyValidAsset(asset_address) {
        uint256 amount_left = asset_amount;
        for (uint i = 0; i < asset_available_amo_array[asset_address].length; i++) { 
            address amo_address = asset_available_amo_array[asset_address][i];
            if (address(0) != amo_address) { // valid amos
                uint256 amo_balance = IAMO(amo_address).AssetBalance(asset_address);
                if (amo_balance < amount_left) {
                    IAMO(amo_address).WithdrawAsset(asset_address, amo_balance);
                    amount_left = amount_left - amo_balance;
                } else {
                    IAMO(amo_address).WithdrawAsset(asset_address, amount_left);
                    amount_left = 0;
                    break;
                }
            }
        }
        require(amount_left == 0);
        TransferToken(asset_address, pool_address, asset_amount);
    }

    /****** PUBLIC FUNCTIONS ******/

    // Everyone can call this collect Profit function, as long as they are willing to pay for gas
    function CollectProfitFromAllAMO() external {
        require((block.timestamp >= last_mint_timestamp) && (block.timestamp - last_mint_timestamp >= mint_interval), "Mint interval not reached");
        last_mint_timestamp = block.timestamp;
        for (uint i = 0; i < amo_array.length; i++) { 
            address amo_address = amo_array[i];
            if (address(0) != amo_address) { // valid amos
                CollectProfitFromAMO(amo_address);
            }
        }
    }

    // return balance of specific AMO and specific asset
    function AMOAssetBalance(address asset_address, address amo_address) external view ValidAMO(amo_address) returns (uint256) {
        return IAMO(amo_address).AssetBalance(asset_address);
    }

    function AMOAssetDollarBalance(address asset_address, address amo_address) external view onlyValidAsset(asset_address) ValidAMO(amo_address) returns (uint256) {
        // NOTE: currently returns e18 view
        uint256 asset_balance = IAMO(amo_address).AssetBalance(asset_address);
        uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
        return asset_balance * asset_price / PRICE_PRECISION;
        // return asset_price;
    }

    function AMOAvailableAssets(address amo_address) external view ValidAMO(amo_address) returns (address[] memory) {
        return IAMO(amo_address).getAvailableAssets();
    }

    function AMODollarBalance(address amo_address) external view ValidAMO(amo_address) returns (uint256) {
        IAMO amo = IAMO(amo_address);
        uint256 dollar_balance = 0;
        for (uint i = 0; i < amo.getAvailableAssets().length; i++) {
            // NOTE: here we assume that all assets in the array are correct
            address asset_address = amo.getAvailableAssets()[i];
            uint256 asset_balance = IAMO(amo_address).AssetBalance(asset_address);
            uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
            dollar_balance += asset_balance * asset_price / PRICE_PRECISION;
        }
        return dollar_balance;
    }

    // NOTE (Gary 2022.5.3): amo total balance can be computed in frontend
    // function AMODollarBalance() external view returns (uint256) {
    //     IAssetManager asset_manager = IAssetManager(asset_manager_address);
    //     uint256 dollar_balance = 0;
    //     for (uint i = 0; i < asset_manager.asset_array().length; i++) {
    //         address asset_address = asset_manager.asset_array()[i];
    //         if (asset_address != address(0)) {
    //             uint256 asset_balance = IERC20(asset_address).balanceOf(address(this));
    //             uint256 asset_price = IOracle(oracle_address).getPrice(asset_address);
    //             dollar_balance += asset_balance * asset_price / PRICE_PRECISION;
    //         }
    //     }
    //     return dollar_balance;
    // }
}