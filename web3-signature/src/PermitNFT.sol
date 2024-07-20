// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {console} from "forge-std/console.sol";


contract PermitNFT is ERC721("CJWNFT", "CJW"), EIP712("PermitNFT", "1"), Ownable(msg.sender), Nonces {


    event Mint(address indexed minter, uint nonce, uint indexed tokenId);

    uint256 private nonce = 0;
    uint256 public constant TOKEN_LIMIT = 666;

    function mint(address user) external payable onlyOwner returns (uint) {
        // generate a tokenId
        uint256 tokenId = uint256(keccak256(abi.encodePacked(msg.sender, block.prevrandao, block.timestamp))) % TOKEN_LIMIT;
        _safeMint(user, tokenId);
        emit Mint(user, nonce, tokenId);
        return tokenId;
    }

    bytes32 public constant NFT_PERMIT_TYPEHASH =
        keccak256("PermitNFT(address owner,address operator,address nftContract,uint256 tokenId,uint256 deadline)");
    function permit(
        uint256 tokenId, 
        address operator, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        address nftOwner = _ownerOf(tokenId);
        bytes32 structHash = keccak256(
                abi.encode(
                    NFT_PERMIT_TYPEHASH,
                    nftOwner,
                    operator,
                    address(this),
                    tokenId,
                    deadline
                )
            );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == nftOwner, "Invalid signature");
        _approve(operator, tokenId, nftOwner);
    }

    function getHashData(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    function getPermitTypehash() public pure returns (bytes32) {
        return NFT_PERMIT_TYPEHASH;
    }
    
}