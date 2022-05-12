const { ethers } = require("hardhat");

async function  mian(){
   
    const test = await ethers.getContractFactory("test");
    const greeter = await test.deploy();
    await greeter.deployed();

    const setGreetingTx = await greeter.setAmount(1);

    // // wait until the transaction is mined
    // console.log(setGreetingTx)
    // await setGreetingTx.wait();
  
 }
  
 
 
mian();