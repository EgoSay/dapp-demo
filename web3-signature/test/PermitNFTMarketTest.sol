// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {console, StdCheats, Test} from "forge-std/Test.sol";
import {PermitERC20Token} from "../src/PermitERC20Token.sol";
import {PermitNFTMarket} from "../src/PermitNFTMarket.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {IERC20Permit, ERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract PermitNFTMarketTest is Test {
 
    uint256 internal whitelistSignerPrivateKey = 0xA1111;
    address whitelistSigner = vm.addr(whitelistSignerPrivateKey);

    uint256 internal buyerPrivateKey = 0xB1111;
    address buyer = vm.addr(buyerPrivateKey);
    uint256 internal sellerPrivateKey = 0xC1111;
    address seller = vm.addr(sellerPrivateKey);

    PermitNFTMarket market;
    PermitERC20Token token;
    MyNFT nftContract;
    uint256 nftDeafultPrice = 888 * 10**18;
    uint256 init_price = 1000 * 10**18;

    bytes32 public constant LISTING_TYPEHASH =
        keccak256("PermitNFTMarketList(address seller,address nftContract,uint256 tokenId,uint256 price)");
    bytes32 public constant WL_TYPEHASH =
        keccak256("PermitNFTWhiteList(address wlSigner, address user)");

    // Mappingto track nft tokenId and it's owner
    mapping(address => uint256) nftOwnerMap;


    function setUp() public {
        nftContract = new MyNFT();
        token = new PermitERC20Token();
        market = new PermitNFTMarket(address(token), whitelistSigner);

        // mint nft 给 seller 
        string memory tokenURI = generateRandomURI();
        uint256 tokenId = nftContract.mint(seller, tokenURI);
        nftOwnerMap[seller] = tokenId;

        // 上架 nft
        vm.startPrank(seller);
        nftContract.approve(address(market), tokenId);
        bool listedRsult = market.list(address(nftContract), tokenId, nftDeafultPrice);
        assertTrue(listedRsult);
        vm.stopPrank();
    }

     function generateRandomURI() public view returns (string memory) {
        bytes32 seed = keccak256(abi.encodePacked(block.number, tx.origin));
        bytes memory randomBytes = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            randomBytes[i] = seed[i];
        }
        return string(randomBytes);
    }

    function testPermitBuyNFT() public {
        (uint8 v1, bytes32 r1, bytes32 s1) =vm.sign(whitelistSignerPrivateKey, getSignatureForWL());
        bytes memory signatureForWL = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(sellerPrivateKey, getSignatureForSellOrder());
        bytes memory signatureForSellOrder = abi.encodePacked(r2, s2, v2);

        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(buyerPrivateKey, getSignatureForApprove());
        bytes memory signatureForApprove = abi.encodePacked(r3, s3, v3);

        // buyer 执行购买
        doPermitBuy(signatureForWL, signatureForSellOrder, signatureForApprove);

        // 验证 nft owner 是否转移
        assertEq(buyer, nftContract.ownerOf(nftOwnerMap[seller]));
        // 验证 user 和 buyer 余额 token 是否正确
        assertEq(token.balanceOf(buyer), (init_price - nftDeafultPrice));
        assertEq(token.balanceOf(seller), (nftDeafultPrice));
    }

    function getSignatureForWL() view private returns (bytes32){
        bytes32 signatureForWLDigest = market.getHashData(
                keccak256(abi.encode(
                    WL_TYPEHASH,
                    whitelistSigner,
                    buyer
                )));
        return signatureForWLDigest;
    }

    function getSignatureForSellOrder() view private returns (bytes32){
        uint256 tokenId = nftOwnerMap[seller];
        return market.getHashData(
                keccak256(abi.encode(
                    LISTING_TYPEHASH,
                    seller,
                    address(nftContract),
                    tokenId,
                    nftDeafultPrice
            )));
    }

    function getSignatureForApprove () view private returns (bytes32){
        uint256 nonce = token.nonces(buyer);
        uint256 deadline = block.timestamp + 1 days;
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
        uint256 deadline = block.timestamp + 1 days;
        deal(address(token), buyer, init_price);
        deal(buyer, init_price);

        // buyer 执行购买
        vm.startPrank(buyer);
        bool buyResult = market.permitBuy(address(nftContract), tokenId, deadline, signatureForWL, signatureForSellOrder, signatureForApprove);
        assertTrue(buyResult);
        vm.stopPrank();
    }
}