//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

interface IMockSwap {
    function swapAssetToSC(address _token, uint _amountIn) external returns(uint);
}