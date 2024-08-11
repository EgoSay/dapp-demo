// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {console, StdCheats, Test} from "forge-std/Test.sol";
import {PermitERC20Token} from "../src/PermitERC20Token.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {PermitNFT} from "../src/PermitNFT.sol";
import {IERC20Permit, ERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AirdopMerkleNFTMarketTest is Test {
 
    uint256 internal whitelistSignerPrivateKey = 0xA1111;
    address whitelistSigner = vm.addr(whitelistSignerPrivateKey);

    uint256 internal buyerPrivateKey = 0xB1111;
    address buyer = vm.addr(buyerPrivateKey);
    uint256 internal sellerPrivateKey = 0xC1111;
    address seller = vm.addr(sellerPrivateKey);

    AirdopMerkleNFTMarket market;
    PermitERC20Token token;
    PermitNFT nftContract;
    uint256 nftDeafultPrice = 888 * 10**18;
    uint256 init_price = 1000 * 10**18;
    uint256 deadline = block.timestamp + 1 days;

    // Mappingto track nft tokenId and it's owner
    mapping(address => uint256) nftOwnerMap;
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    function setUp() public {
        nftContract = new PermitNFT();
        token = new PermitERC20Token();

        // Create Merkle tree
        // hash0-0: 0x36d351db319e43161106cc568588e212d0003259607e5ba5c5e4fc502af5fe7b = hashPair(user1, user2)
        // hash0-1: 0xfc263b9aeb45e8ea5a0808acc65dbf7a5a3854e5bd26d37d34b8c40485b42f02 = hashPair(whitelistSigner, buyer)
        // hash root: 0x417701255d5c81b9b133d18de5c8376c66612d2d60ef45e372617dd847b22b37 = hashPair(hash0-0, hash0-1)
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256(abi.encodePacked(user1));
        leaves[1] = keccak256(abi.encodePacked(user2));
        leaves[2] = keccak256(abi.encodePacked(whitelistSigner));
        leaves[3] = keccak256(abi.encodePacked(buyer));

        bytes32 root = getMerkleRoot(leaves); 
        market = new AirdopMerkleNFTMarket(root);

        // mint nft 给 seller 
        uint256 tokenId = nftContract.mint(seller);
        nftOwnerMap[seller] = tokenId;
        vm.prank(seller);
        nftContract.approve(address(market), tokenId);
        market.setWhiteListSigner(whitelistSigner);
    }

    function testMulticallAndMerkle() public {

         // nft owner 签名授权 nftMarket 上架出售
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(sellerPrivateKey, getSignatureForNft());
        bytes memory signatureForNft = abi.encodePacked(r1, s1, v1);

        // 上架 nft
        _prepareListNft(signatureForNft);


        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(buyerPrivateKey, getSignatureForTokenApprove());
        bytes memory signatureForApprove = abi.encodePacked(r2, s2, v2);

        // buyer 执行购买
        doPermitBuy(signatureForApprove);

        // 验证 nft owner 是否转移
        assertEq(buyer, nftContract.ownerOf(nftOwnerMap[seller]));
        // 验证 user 和 buyer 余额 token 是否正确
        uint256 sellPrice = nftDeafultPrice * market.DISCOUNT_RATE() / 100;
        assertEq(token.balanceOf(buyer), (init_price - sellPrice));
        assertEq(token.balanceOf(seller), (sellPrice));
    }

    function doPermitBuy(bytes memory tokenSignature) private {
        uint256 tokenId = nftOwnerMap[seller];
        deal(address(token), buyer, init_price);
        deal(buyer, init_price);

        // buyer 执行购买
        vm.startPrank(buyer);
        // Prepare multicall data
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = abi.encodeWithSignature("permitPrePay(address,uint256,bytes)", address(nftContract), tokenId, tokenSignature);

        // Prepare Merkle proof
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256(abi.encodePacked(whitelistSigner));
        
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user1));
        leaves[1] = keccak256(abi.encodePacked(user2));
        proof[1] = getMerkleRoot(leaves);
        multicallData[1] = abi.encodeWithSignature("claimNFT(address,uint256,bytes32[])", address(nftContract), tokenId, proof);
        market.multicall(multicallData);
        vm.stopPrank();
    }

    function getMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "No leaves");
        if (leaves.length == 1) {
            return leaves[0];
        }

        bytes32[] memory nextLevel = new bytes32[]((leaves.length + 1) / 2);
        for (uint i = 0; i < nextLevel.length; i++) {
            if (2 * i + 1 < leaves.length) {
                nextLevel[i] = keccak256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
            } else {
                nextLevel[i] = leaves[2 * i];
            }
        }

        return getMerkleRoot(nextLevel);
    }

        function _prepareListNft(bytes memory signatureForNft) private {
        // 上架 nft
        vm.startPrank(seller);
        bool listedRsult =  market.list(address(nftContract), nftOwnerMap[seller], address(token), nftDeafultPrice, deadline, signatureForNft);
        assertTrue(listedRsult);
        vm.stopPrank();
    }

    function getSignatureForNft() view private returns (bytes32){
        uint256 tokenId = nftOwnerMap[seller];
        bytes32 structHash = keccak256(abi.encode(
                    nftContract.getPermitTypehash(),
                    seller,
                    address(market),
                    address(nftContract),
                    tokenId,
                    deadline
            ));
        return nftContract.getHashData(structHash);
    }

    function getSignatureForTokenApprove () view private returns (bytes32){
        uint256 nonce = token.nonces(buyer);
        // 签名
        return token.getHashData(
                keccak256(abi.encode(
                    token.getPermitTypehash(),
                    buyer,
                    address(market),
                    nftDeafultPrice,
                    nonce,
                    deadline
                ))
            );
    }
}