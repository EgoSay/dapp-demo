// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyNFT is ERC721URIStorage, Ownable {


    event Mint(address indexed minter, uint nonce, uint indexed tokenId);

    uint internal nonce = 0;
    uint public constant TOKEN_LIMIT = 666;

    constructor () ERC721 ("CJWNFTS", "CJW") Ownable(msg.sender) {
    }

    function mint(address user, string memory tokenURI) external payable onlyOwner returns (uint) {
        // generate a tokenId
        uint256 tokenId = uint256(keccak256(abi.encodePacked(nonce, msg.sender, block.prevrandao, block.timestamp))) % TOKEN_LIMIT;
        _safeMint(user, tokenId);
        _setTokenURI(tokenId, tokenURI);
        nonce += 1;
        emit Mint(user, nonce, tokenId);
        return tokenId;
    }

    
}