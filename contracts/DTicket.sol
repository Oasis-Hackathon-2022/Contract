// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

//  _____     ______     ______   ______     ______     __     ______  
// /\  __-.  /\  ___\   /\  == \ /\  __ \   /\  ___\   /\ \   /\__  _\ 
// \ \ \/\ \ \ \  __\   \ \  _-/ \ \ \/\ \  \ \___  \  \ \ \  \/_/\ \/ 
//  \ \____-  \ \_____\  \ \_\    \ \_____\  \/\_____\  \ \_\    \ \_\ 
//   \/____/   \/_____/   \/_/     \/_____/   \/_____/   \/_/     \/_/ 

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IPool.sol";

contract DTicket is ERC721 {

    IPool private pool;

    constructor(address _pool)  ERC721("DTicket-NFT","DT-NFT") {
        pool = IPool(_pool);
    }

    modifier onlyOwnerOf(address owner, uint _tokenId) {
        require(owner == ownerOf(_tokenId),'The NFT is not yours');
        _;
    }

    modifier onlyPool() {
        require(msg.sender == address(pool),'only Pool');
        _;
    }

    function transfer(address _to, uint _tokenId) public {
        _transfer(msg.sender, _to, _tokenId);
        pool.transferTicketOwner(_tokenId, _to);
    }

    function mintToken(address to, uint tokenId) external onlyPool{
         _mint(to, tokenId);
    }

    function burnToken(address owner, uint _tokenId) external onlyPool onlyOwnerOf(owner,_tokenId){
        _burn(_tokenId);
    }

}