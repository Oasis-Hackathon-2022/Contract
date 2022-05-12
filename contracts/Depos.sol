//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Depos is ERC20, Ownable {

    address public pool_address;
    address public buyback_vault_address;
    address public oracle_address;
    
    /****** MODIFIER ******/

    modifier onlyPool() {
        require(msg.sender == pool_address, "Only pool can mint new Depos");
        _;
    }

    modifier onlyBuybackVault() {
        require(msg.sender == buyback_vault_address, "Only buyback vault can burn Depos");
        _;
    }


    // initialSupply = 1,000,000e18 
    constructor(
        uint256 initialSupply,
        address _oracle_address
    ) ERC20("Depos", "DEPOS") {
        require(_oracle_address != address(0), "Zero address detected"); 
        _mint(msg.sender, initialSupply);
        oracle_address = _oracle_address;
    }
    /****** RESTRICTED FUNCTIONS ******/
    function setOracle(address new_oracle) external onlyOwner {
        require(new_oracle != address(0), "Zero address detected");
        oracle_address = new_oracle;
    }

    function setPoolAddress(address new_pool) external onlyOwner {
        require(new_pool != address(0), "Zero address detected");
        pool_address = new_pool;
    }

    function setBuybackVaultAddress(address new_buyback_vault) external onlyOwner {
        require(new_buyback_vault != address(0), "Zero address detected");
        buyback_vault_address = new_buyback_vault;
    }

    function mint(address to, uint256 amount) public onlyPool {
        _mint(to, amount);
    }

    function pool_mint(address mint_address, uint256 amount) external onlyPool {
        _mint(mint_address, amount);
        emit DEPOSMinted(address(this), mint_address, amount);
    }

    function pool_burn_from(address burn_address, uint256 amount) external onlyBuybackVault {
        _burn(burn_address, amount);
        emit DEPOSBurned(burn_address, address(this), amount);
    }

    /****** PUBLIC FUNCTIONS ******/


    /****** EVENTS ******/
    // Track Depos burned
    event DEPOSBurned(address indexed from, address indexed to, uint256 amount);

    // Track Depos minted
    event DEPOSMinted(address indexed from, address indexed to, uint256 amount);
}