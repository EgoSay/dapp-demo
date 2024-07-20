// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {console, StdCheats, Test} from "forge-std/Test.sol";
import {PermitERC20Token} from "../src/PermitERC20Token.sol";
import {PermitNFTMarket} from "../src/PermitNFTMarket.sol";
import {PermitNFT} from "../src/PermitNFT.sol";
import {IERC20Permit, ERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PermitNFTMarketTest is Test {
 
    uint256 internal whitelistSignerPrivateKey = 0xA1111;
    address whitelistSigner = vm.addr(whitelistSignerPrivateKey);

    uint256 internal buyerPrivateKey = 0xB1111;
    address buyer = vm.addr(buyerPrivateKey);
    uint256 internal sellerPrivateKey = 0xC1111;
    address seller = vm.addr(sellerPrivateKey);

    PermitNFTMarket market;
    PermitERC20Token token;
    PermitNFT nftContract;
    uint256 nftDeafultPrice = 888 * 10**18;
    uint256 init_price = 1000 * 10**18;
    uint256 deadline = block.timestamp + 1 days;

    // Mappingto track nft tokenId and it's owner
    mapping(address => uint256) nftOwnerMap;


    function setUp() public {
        nftContract = new PermitNFT();
        token = new PermitERC20Token();
        market = new PermitNFTMarket();

        // mint nft 给 seller 
        uint256 tokenId = nftContract.mint(seller);
        nftOwnerMap[seller] = tokenId;
        vm.prank(seller);
        nftContract.approve(address(market), tokenId);
        market.setWhiteListSigner(whitelistSigner);
    }

    function testPermitBuyNFT() public {

         // nft owner 签名授权 nftMarket 上架出售
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(sellerPrivateKey, getSignatureForNft());
        bytes memory signatureForNft = abi.encodePacked(r2, s2, v2);

        // 上架 nft
        vm.startPrank(seller);
        bool listedRsult = prepareListNft(signatureForNft);
        assertTrue(listedRsult);
        vm.stopPrank();

        (uint8 v1, bytes32 r1, bytes32 s1) =vm.sign(whitelistSignerPrivateKey, getSignatureForWL());
        bytes memory signatureForWL = abi.encodePacked(r1, s1, v1);

        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(buyerPrivateKey, getSignatureForTokenApprove());
        bytes memory signatureForApprove = abi.encodePacked(r3, s3, v3);

        // buyer 执行购买
        doPermitBuy(signatureForWL, signatureForNft, signatureForApprove);

        // 验证 nft owner 是否转移
        assertEq(buyer, nftContract.ownerOf(nftOwnerMap[seller]));
        // 验证 user 和 buyer 余额 token 是否正确
        assertEq(token.balanceOf(buyer), (init_price - nftDeafultPrice));
        assertEq(token.balanceOf(seller), (nftDeafultPrice));
    }

    function prepareListNft(bytes memory signatureForNft) private returns(bool) {
        // 上架 nft
        return market.list(address(nftContract), 
                            nftOwnerMap[seller], 
                            address(token), 
                            nftDeafultPrice, 
                            deadline, 
                            signatureForNft);
    }

    function getSignatureForWL() view private returns (bytes32){
        bytes32 signatureForWLDigest = market.getHashData(
                keccak256(abi.encode(
                    market.getPermitTypehash(),
                    whitelistSigner,
                    buyer
                )));
        console.logBytes32(signatureForWLDigest);
        return signatureForWLDigest;
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

    function doPermitBuy(
        bytes memory signatureForWL,
        bytes memory signatureForSellOrder,
        bytes memory signatureForApprove
    ) private {
        uint256 tokenId = nftOwnerMap[seller];

        deal(address(token), buyer, init_price);
        deal(buyer, init_price);

        // buyer 执行购买
        vm.startPrank(buyer);
        bool buyResult = market.permitBuy(address(nftContract), tokenId, signatureForWL, signatureForSellOrder, signatureForApprove);
        assertTrue(buyResult);
        vm.stopPrank();
    }
}