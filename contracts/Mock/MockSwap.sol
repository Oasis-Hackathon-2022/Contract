//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

import "./IMockERC20.sol";
import "./MockERC20.sol";
import "../Interface/ERC20Helper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// a mock swap platform that 
contract MockSwap is ERC20Helper,Ownable {
    event SwapAssetToSC(address user, uint amountIn, uint amountOut);
    address public mockERC20;

    mapping(address => Reverse) public assetReverseMap;

    struct Reverse {
        uint assetsReverse;
        uint scTokenReverse;
        uint k;
    }

    constructor() {
        
    }

    function setMockERC20(address _mockERC20) external onlyOwner {
        mockERC20 = _mockERC20;
    }

    function swapAssetToSC(address _token, uint _amountIn) external returns(uint amountOut) {
        if (assetReverseMap[_token].scTokenReverse==0) {
            assetReverseMap[_token].scTokenReverse = 10**25;
            assetReverseMap[_token].assetsReverse = 10**25;
            assetReverseMap[_token].k = 10**50;
        }
        assetReverseMap[_token].assetsReverse += _amountIn;
        uint old_reserve = assetReverseMap[_token].scTokenReverse;
        assetReverseMap[_token].scTokenReverse = assetReverseMap[_token].k/assetReverseMap[_token].assetsReverse;
        amountOut = old_reserve - assetReverseMap[_token].scTokenReverse;
        assetReverseMap[_token].k = assetReverseMap[_token].assetsReverse*assetReverseMap[_token].scTokenReverse;

        IMockERC20(mockERC20).mint_to_mock_swap(amountOut);
        TransferToken(mockERC20, msg.sender, amountOut);
        emit SwapAssetToSC(msg.sender, _amountIn, amountOut);
    }
}