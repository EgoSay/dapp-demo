// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {PermitNFTMarket} from "./PermitNFTMarket.sol";


contract AirdopMerkleNFTMarket is PermitNFTMarket {
    
    uint256 public constant DISCOUNT_RATE = 50;
    bytes32 public merkleRoot;

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    function _verify(bytes32[] memory proof, address addr) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function permitPrePay(address nftAddress, uint256 tokenId, bytes calldata tokenSignature) public {
        // find the nft order id
        bytes32 orderId = listing(nftAddress, tokenId);
        require(orderId != bytes32(0), "PermitNFTMarket: order not listed");
        NftOrderInfo memory nftOrder = nftOrders[orderId];
         _tokenPermit(nftOrder, tokenSignature);
        emit PermitPrePay(nftAddress, tokenId);
    }

    function claimNFT(address nftAddress, uint256 tokenId, bytes32[] calldata merkleProof) public {
        // find the nft order id
        bytes32 orderId = listing(nftAddress, tokenId);
        require(orderId != bytes32(0), "PermitNFTMarket: order not listed");
        buyWithDiscount(orderId, merkleProof, DISCOUNT_RATE);
        emit ClaimNFT(nftAddress, tokenId);
    }

    // buy with discount
    function buyWithDiscount(bytes32 orderId, bytes32[] calldata merkleProof, uint256 discountRate) public payable {
        require(_verify(merkleProof, msg.sender), "AirdopMerkleNFTMarket: invalid merkle proof");
        _buy(orderId, feeTo, discountRate);
    }

    function multicall(bytes[] calldata datas) public returns (bytes[] memory results) {
        results = new bytes[](datas.length);
        for (uint256 i = 0; i < datas.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), datas[i]);
        }
        return results;
    }

    event PermitPrePay(address indexed nftAddress, uint256 indexed tokenId);
    event ClaimNFT(address indexed nftAddress, uint256 indexed tokenId);

}