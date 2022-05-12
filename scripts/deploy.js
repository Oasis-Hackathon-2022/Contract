// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { parseUnits } = require("ethers/lib/utils");
const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  // const Greeter = await hre.ethers.getContractFactory("Greeter");
  // const greeter = await Greeter.deploy("Hello, Hardhat!");

  // await greeter.deployed();

  // console.log("Greeter deployed to:", greeter.address);
  const Oracle = await hre.ethers.getContractFactory("Oracle");
  let oracle = await Oracle.deploy();
  await oracle.deployed();

  const MockSwap = await hre.ethers.getContractFactory("MockSwap");
  let mockSwap = await MockSwap.deploy();
  await mockSwap.deployed();

  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  let USDC = await MockERC20.deploy("USDC", "USDC", 18, mockSwap.address);
  let ETH = await MockERC20.deploy("ETH", "ETH", 18, mockSwap.address);
  await USDC.deployed();
  await ETH.deployed();
  await mockSwap.setMockERC20(USDC.address);
  await oracle.setPrice(USDC.address, parseUnits("1", 6));
  await oracle.setPrice(ETH.address, parseUnits("2000", 6));
  
  const AssetManager = await ethers.getContractFactory("AssetManager");
  let assetManager = await AssetManager.deploy();
  await assetManager.deployed();
  await assetManager.addAsset(USDC.address);
  await assetManager.addAsset(ETH.address);

  const Depos = await ethers.getContractFactory("Depos");
  let depos = await Depos.deploy(parseUnits("1000000", 18), oracle.address);
  await depos.deployed();
  await oracle.setPrice(depos.address, parseUnits("10", 6));

  const AMOManager = await ethers.getContractFactory("AMOManager");
  let amoManager = await AMOManager.deploy(assetManager.address, oracle.address);
  await amoManager.deployed();

  const ExampleAMO = await ethers.getContractFactory("Example_AMO");
  let usdc_exampleAMO = await ExampleAMO.deploy(amoManager.address, USDC.address);
  let eth_exampleAMO = await ExampleAMO.deploy(amoManager.address, ETH.address);
  await usdc_exampleAMO.deployed();
  await eth_exampleAMO.deployed();
  await amoManager.AddAMO(usdc_exampleAMO.address);
  await amoManager.AddAMO(eth_exampleAMO.address);
  await amoManager.AddAssetAmo(USDC.address, usdc_exampleAMO.address);
  await amoManager.AddAssetAmo(ETH.address, eth_exampleAMO.address);

  const InsuranceVault = await ethers.getContractFactory("InsuranceVault");
  let insuranceVault = await InsuranceVault.deploy(depos.address, oracle.address, assetManager.address, amoManager.address, mockSwap.address);
  await insuranceVault.deployed();
  await amoManager.setInsuranceVaultAddress(insuranceVault.address);
  await insuranceVault.addSupportedStablecoin(USDC.address);

  const BuybackVault = await ethers.getContractFactory("BuybackVault");
  let buybackVault = await BuybackVault.deploy(
    depos.address,
    oracle.address,
    assetManager.address,
    amoManager.address
  );
  await buybackVault.deployed();
  await depos.setBuybackVaultAddress(buybackVault.address);
  await amoManager.setBuybackVaultAddress(buybackVault.address);
  
  const Pool = await ethers.getContractFactory("Pool");
  let pool = await Pool.deploy(
    depos.address,
    oracle.address,
    assetManager.address,
    amoManager.address,
    insuranceVault.address
  )
  await pool.deployed();
  await depos.setPoolAddress(pool.address);
  await amoManager.setPoolAddress(pool.address);
  await insuranceVault.setPoolAddress(pool.address);
  await buybackVault.setPoolAddress(pool.address);
  await pool.setCompensateParameters(ETH.address, parseUnits("8", 5), parseUnits("95", 4), 3600, 1)
  await pool.setCompensateParameters(USDC.address, parseUnits("8", 5), parseUnits("99", 4), 3600, 1)

  // TODO: print addresses
  console.log("Oracle address: ", oracle.address);
  console.log("Depos address: ", depos.address);
  console.log("USDC address: ", USDC.address);
  console.log("ETH address: ", ETH.address);
  console.log("mockSwap address: ", mockSwap.address);
  console.log("assetManager address: ", assetManager.address);
  console.log("amoManager address: ", amoManager.address);
  console.log("eth_amo address: ", eth_exampleAMO.address);
  console.log("usdc_amo address: ", usdc_exampleAMO.address);
  console.log("insuranceVault address: ", insuranceVault.address);
  console.log("buybackVault address: ", buybackVault.address);
  console.log("pool address: ", pool.address);


  // TEST ONLY
  // await USDC.approve(pool.address, parseUnits("1", 25))
  // await ETH.approve(pool.address, parseUnits("1", 25))
  // await pool.timeDeposit(USDC.address, parseUnits("1", 18), 10)

  // await amoManager.GiveAssetToAMO(USDC.address, usdc_exampleAMO.address, parseUnits("1", 18))
  // await pool.timeDeposit(ETH.address, parseUnits("1", 21), 10)
  // await pool.timeDeposit(ETH.address, parseUnits("1", 13), 10)
  // await amoManager.GiveAssetToAMO(ETH.address, eth_exampleAMO.address, parseUnits("1", 21))

  // await oracle.setPrice(ETH.address, parseUnits("1500", 6))

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
