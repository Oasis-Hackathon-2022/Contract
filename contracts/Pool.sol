// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "./Interface/ERC20Helper.sol";
import "./IAssetManager.sol";
import "./IOracle.sol";
import "./AMOs/IAMOManager.sol";
import "./IInsuranceVault.sol";
import "./IDepos.sol";
import "./DTicket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pool is ERC20Helper, Ownable {
    event Deposit(address indexed assets,address indexed user,uint amount);
    event Withdraw(address indexed assets,address indexed user,uint amount);

    address public amo_manager_address;
    address public asset_manager_address;
    address public depos_address;
    address public insurance_vault_address;

    DTicket public dTicket;
    
    // price oracle
    address public oracle_address;
    uint256 constant PRICE_PRECISION = 1e6;
    
    mapping(uint => TimeDeposit) timeDepositMap; // id => TimeDeposit
    uint totalInvestors; // investors num
    mapping(address => mapping(address => uint[])) investorIds;// asset address => (user address => id array)

    mapping(address => uint256) public asset_max_compensate_threshold; // e.g., BTC 80% threshold then this for BTC is set to 800000
    mapping(address => uint256) public asset_min_compensate_threshold; // e.g., BTC is set to 950000 (95%), USDC is set to 990000 (99%)
    mapping(address => uint256) public asset_compensate_twap_period;
    mapping(address => uint256) public asset_compensate_weight;

    uint256 public insurance_vault_compensate_ratio;

    mapping(address => uint) private assetProfitMap; // asset address => asset total Profit amount
    mapping(address => uint) private userAssetAmountMap; // asset address => asset total amount
    mapping(uint => uint) private timeDepositMaxCompensation;
    uint256 public total_max_compensation;

    struct TimeDeposit {
        address user;
        address asset;
        uint id;
        uint time;
        uint amount;
        uint price; // NOTE: price at deposit (1 hr twap)
        bool isWithdraw;
    }

    constructor(
        address _depos_address,
        address _oracle_address,
        address _asset_manager_address,
        address _amo_manager_address,
        address _insurance_vault_address
    ) {
        require((_depos_address != address(0)) && (_oracle_address != address(0)) && (_asset_manager_address != address(0)) && (_amo_manager_address != address(0)) && (_insurance_vault_address != address(0)), "Zero address detected");
        depos_address = _depos_address;
        oracle_address = _oracle_address;
        asset_manager_address = _asset_manager_address;
        amo_manager_address = _amo_manager_address;
        insurance_vault_address = _insurance_vault_address;
        total_max_compensation = 0;
        insurance_vault_compensate_ratio = 800000;
        dTicket = new DTicket(address(this));
    }


    /****** MODIFIERS ******/
    modifier onlyValidAsset(address asset_address) {
        require(IAssetManager(asset_manager_address).assetAvailable(asset_address) == true, "Asset not available");
        _;
    }

    modifier onlyAMOManager() {
        require(msg.sender == amo_manager_address, "You are not amo manager");
        _;
    }

    modifier onlyDTicket() {
        require(msg.sender == address(dTicket), "You are not DTicket");
        _;
    }

    function transferTicketOwner(uint _tokenId,address newOwner) external onlyDTicket() {
        address lastOnwer = timeDepositMap[_tokenId].user;
        uint[] memory idsTmp = investorIds[timeDepositMap[_tokenId].asset][lastOnwer];
        for(uint i = 0; i<idsTmp.length; i++) {
            if(idsTmp[i] == _tokenId) {
                investorIds[timeDepositMap[_tokenId].asset][lastOnwer][i] = investorIds[timeDepositMap[_tokenId].asset][lastOnwer][idsTmp.length-1];
                investorIds[timeDepositMap[_tokenId].asset][lastOnwer].pop();
            }
        }
        timeDepositMap[
            _tokenId
        ].user = newOwner;
        investorIds[
            timeDepositMap[_tokenId].asset
        ][newOwner].push(
            _tokenId
        );
    }

    function setCompensateParameters(address asset_address, uint256 max_threshold, uint256 min_threshold, uint256 twap_period, uint256 compensate_weight) external onlyValidAsset(asset_address) onlyOwner {
        require((min_threshold >= max_threshold) && (min_threshold <= PRICE_PRECISION), "Invalid parameters");
        asset_max_compensate_threshold[asset_address] = max_threshold;
        asset_min_compensate_threshold[asset_address] = min_threshold;
        // TODO: add modifier
        asset_compensate_twap_period[asset_address] = twap_period;
        // TODO: add modifier
        asset_compensate_weight[asset_address] = compensate_weight;
    }

    function AssetTotalDepositAmount(address asset_address) public view onlyValidAsset(asset_address) returns (uint256) {
        return userAssetAmountMap[asset_address];
    }

    function AssetTotalProfit(address asset_address) public view onlyValidAsset(asset_address) returns (uint256) {
        return assetProfitMap[asset_address];
    }

    // returns total compensation in **dollar** value
    // function EstimateAssetCompensation(address asset_address) internal onlyValidAsset(asset_address) returns(uint256) {
    //     uint256 asset_amount = AssetTotalDepositAmount(asset_address);
    //     uint256 asset_price = IOracle(oracle_address).getTWAP(asset_address, asset_compensate_twap_period[asset_address]);
    //     // TODO: we need decimals!!!
    //     uint8 decimals = IERC20(asset_address).decimals();
    //     for (uint i = 0; i < totalInvestors; i++) {

    //     }
    // }

    // returns gamma with 1e6 factor
    function GetGammaFactor() public view returns (uint256) {
        // IAssetManager asset_manager = IAssetManager(asset_manager_address);
        // uint256 total_estimated_compensation = total_max_compensation;
        // for (uint i = 0; i < asset_manager.getAssetArray().length; i++) {
        //     address asset_address = asset_manager.getAssetArray()[i];
        //     if (asset_address != address(0)) {
        //         total_estimated_compensation += EstimateAssetCompensation(asset_address);
        //     }
        // }
        if (total_max_compensation == 0) return 0;
        uint256 insurance_vault_dollar_balance = IInsuranceVault(insurance_vault_address).VaultDollarBalance();
        uint256 gamma_raw = insurance_vault_dollar_balance * insurance_vault_compensate_ratio / total_max_compensation;
        if (gamma_raw > PRICE_PRECISION) gamma_raw = PRICE_PRECISION;
        return gamma_raw;
    }

    function AmountToCompensateUser(uint256 _tokenId) public view returns (uint256 amount_to_compensate) {
        require(_tokenId <= totalInvestors, "tokenID unavailable");
        uint256 p0 = timeDepositMap[_tokenId].price;
        address asset = timeDepositMap[_tokenId].asset;
        uint256 deposited_amount = timeDepositMap[_tokenId].amount;
        uint256 p = IOracle(oracle_address).getTWAP(asset, asset_compensate_twap_period[asset]); // 1 hr twap
        uint8 decimals = IERC20(asset).decimals();
        if (p * PRICE_PRECISION >= asset_min_compensate_threshold[asset] * p0) {
            amount_to_compensate = 0;
        } else if (p * PRICE_PRECISION <= asset_max_compensate_threshold[asset] * p0) {
            amount_to_compensate = deposited_amount * (asset_min_compensate_threshold[asset] - asset_max_compensate_threshold[asset]) * p0 / PRICE_PRECISION / (10 ** decimals);
        } else {
            amount_to_compensate = deposited_amount * (asset_min_compensate_threshold[asset] * p0 - PRICE_PRECISION * p) / PRICE_PRECISION / (10 ** decimals);
        }
        amount_to_compensate = amount_to_compensate * GetGammaFactor() / PRICE_PRECISION;
    }

    function TriggerCompensation(address user_address, uint256 amount_in_dollar) internal {
        IInsuranceVault insurance_vault = IInsuranceVault(insurance_vault_address);
        insurance_vault.ExecuteCompensation(user_address, amount_in_dollar);
    }

    /****** RESTRICTED FUNCTIONS ******/
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

    function setInsuranceVaultAddress(address new_insurance_vault) external onlyOwner {
        require(new_insurance_vault != address(0), "Zero address detected");
        insurance_vault_address = new_insurance_vault;
    }

    /****** PUBLIC FUNCTIONS ******/
    function timeDeposit(address asset, uint amount, uint time) external {
        _deposit(asset, amount);
        dTicket.mintToken(msg.sender, totalInvestors);
        uint256 price = IOracle(oracle_address).getTWAP(asset, 3600);
        timeDepositMap[
            totalInvestors
        ] = TimeDeposit(
            msg.sender,
            asset,
            totalInvestors,
            block.timestamp + time,
            amount,
            price,
            false
        );
        // NOTE: set stablecoin max_threshold high, e.g., 999990
        timeDepositMaxCompensation[totalInvestors] = (PRICE_PRECISION - asset_max_compensate_threshold[asset]) * amount * price / (uint256(10) ** IERC20(asset).decimals()) / PRICE_PRECISION;
        total_max_compensation += timeDepositMaxCompensation[totalInvestors];
        userAssetAmountMap[asset] += amount;
        investorIds[asset][msg.sender].push(
            totalInvestors
        );
        totalInvestors = totalInvestors + 1;
    }

    function timeWithdraw(uint _tokenId) external {
        require(msg.sender == dTicket.ownerOf(_tokenId),"The NFT is not yours.");
        require(timeDepositMap[
            _tokenId
        ].isWithdraw == false, "You have already withdrawn.");
        address asset = timeDepositMap[_tokenId].asset;
        // user asset amount
        uint amount = timeDepositMap[_tokenId].amount;
        uint balance = IERC20(asset).balanceOf(address(this));
        // user asset profit amount
        uint profitAmount = 0;
        if (block.timestamp > timeDepositMap[_tokenId].time) {
            profitAmount = amount * assetProfitMap[asset] / userAssetAmountMap[asset];
            // TODO:cal Depos token amount
            // IDepos(depos_address).pool_mint(msg.sender, uint256 amount);
        }
        uint total_amount = amount + profitAmount;
        if (balance < total_amount) {
            IAMOManager(amo_manager_address).WithdrawAssetFromAMO(asset, total_amount - balance);
        }
        // TODO: else profit goes to insurance vault
        _withdraw(
            asset,
            total_amount
        );
        userAssetAmountMap[
            asset
        ] -= amount;
        assetProfitMap[asset] -= profitAmount;
        timeDepositMap[
            _tokenId
        ].isWithdraw = true;
        // compensate
        uint256 amount_to_compensate = AmountToCompensateUser(_tokenId);
        TriggerCompensation(msg.sender, amount_to_compensate);
        total_max_compensation -= timeDepositMaxCompensation[_tokenId];
        dTicket.burnToken(msg.sender, _tokenId);
    }

    function recordTransferProfitFromAMO(address asset, uint assetAmount) external onlyAMOManager {
        assetProfitMap[asset] += assetAmount;
    }

    function _deposit(address asset, uint amount) onlyValidAsset(asset) internal {
        TransferInToken(asset, msg.sender, amount);
        emit Deposit(asset, msg.sender, amount);
    }

    function _withdraw(address asset, uint amount) onlyValidAsset(asset) internal {
        TransferToken(asset, msg.sender, amount);
        emit Withdraw(asset, msg.sender, amount);
    }

    // function GiveAssetToAMO(address asset_address, uint256 amount) onlyValidAsset(asset_address) internal {
    //     // NOTE: check security
    //     IAMOManager amo_manager = IAMOManager(amo_manager_address);
    //     TransferToken(asset_address, amo_manager_address, amount);
    //     amo_manager.GiveAssetToAMO(asset_address, amount);
    // }

    function WithdrawAssetFromAMO(address asset_address, uint256 amount) onlyValidAsset(asset_address) internal {
        IAMOManager amo_manager = IAMOManager(amo_manager_address);
        amo_manager.WithdrawAssetFromAMO(asset_address, amount); // contains transfer
    }
    
    function GiveAMOAsset(address asset_address, uint256 asset_amount) external onlyValidAsset(asset_address) onlyAMOManager {
        TransferToken(asset_address, amo_manager_address, asset_amount);
    }
}