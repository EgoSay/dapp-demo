// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {console, StdCheats, Test} from "forge-std/Test.sol";
import  "../src/NFTMarketWithOrderSign.sol";
import {PermitNFT} from "../src/PermitNFT.sol";
import {IERC20Permit, ERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract PermitNFTMarketTest is Test {
 
    uint256 internal whitelistSignerPrivateKey = 0xA1111;
    address whitelistSigner = vm.addr(whitelistSignerPrivateKey);

    uint256 internal buyerPrivateKey = 0xB1111;
    address buyer = vm.addr(buyerPrivateKey);
    uint256 internal sellerPrivateKey = 0xC1111;
    address seller = vm.addr(sellerPrivateKey);

    NFTMarketWithOrderSign market;
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    
    PermitNFT nftContract;
    uint256 nftDeafultPrice = 888 ether;
    uint256 init_price = 1000 ether;
    uint256 deadline = block.timestamp + 1 days;

    // Mappingto track nft tokenId and it's owner
    mapping(address => uint256) nftOwnerMap;


    function setUp() public {
        nftContract = new PermitNFT();
        market = new NFTMarketWithOrderSign();

        // mint nft 给 seller 
        uint256 tokenId = nftContract.mint(seller);
        nftOwnerMap[seller] = tokenId;
        vm.prank(seller);
        nftContract.approve(address(market), tokenId);
        market.setWhiteListSigner(whitelistSigner);

    }

    function testPermitBuyNFTWithEth() public {

        // mock 生成一个 order 对象，模拟用户前端交互上架 nft
        NFTMarketWithOrderSign.NftOrderInfo memory nftOrder = _mockOrderInfo();

        (uint8 v1, bytes32 r1, bytes32 s1) =vm.sign(whitelistSignerPrivateKey, getSignatureForWL());
        bytes memory signatureForWL = abi.encodePacked(r1, s1, v1);

         // nft owner 签名授权 nftMarket 上架出售
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(sellerPrivateKey, getSignatureForNft(nftOrder));
        bytes memory signatureForNft = abi.encodePacked(r2, s2, v2);

        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(buyerPrivateKey, getSignatureForTokenApprove());
        bytes memory signatureForApprove = abi.encodePacked(r3, s3, v3);

        // buyer 执行购买
        doPermitBuy(nftOrder, signatureForWL, signatureForNft, signatureForApprove);

        // 验证 nft owner 是否转移
        assertEq(buyer, nftContract.ownerOf(nftOwnerMap[seller]));
        // 验证 user 和 buyer 余额 token 是否正确
        assertEq(buyer.balance, (init_price - nftDeafultPrice));
        assertEq(seller.balance, (nftDeafultPrice));
    }

    function _mockOrderInfo() private view returns(NFTMarketWithOrderSign.NftOrderInfo memory) {
         // Create an NftOrderInfo struct
        return NFTMarketWithOrderSign.NftOrderInfo({
            seller: seller,
            nftContract: address(nftContract),
            payToken: market.ETH_FLAG(),
            tokenId: nftOwnerMap[seller],
            price: nftDeafultPrice,
            deadline: deadline
        });
    }

    function getSignatureForWL() view private returns (bytes32) {
        bytes32 signatureForWLDigest = market.getHashData(
                keccak256(abi.encode(
                    market.WL_TYPEHASH(),
                    whitelistSigner,
                    buyer
                )));
        return signatureForWLDigest;
    }

    function getSignatureForNft(NFTMarketWithOrderSign.NftOrderInfo memory nftOrder) view private returns (bytes32){
        bytes32 structHash = keccak256(abi.encode(
                    market.ORDER_TYPEHASH(),
                    nftOrder.seller, 
                    nftOrder.nftContract,
                    nftOrder.payToken, 
                    nftOrder.tokenId, 
                    nftOrder.price,
                    nftOrder.deadline
            ));
        return market.getHashData(structHash);
    }

    function getSignatureForTokenApprove () view private returns (bytes32){
        uint256 nonce = market.nonces(buyer);
        // 签名
        return market.getHashData(
                keccak256(abi.encode(
                    market.PERMIT_TOKEN_TYPEHASH(),
                    buyer,
                    address(market),
                    market.ETH_FLAG(),
                    nftDeafultPrice,
                    nonce,
                    deadline
                ))
            );
    }

    function doPermitBuy(
        NFTMarketWithOrderSign.NftOrderInfo memory  nftOrder,
        bytes memory signatureForWL,
        bytes memory signatureForSellOrder,
        bytes memory signatureForApprove
    ) private {
        deal(buyer, init_price);

        // buyer 执行购买
        vm.startPrank(buyer);
        // buyer.approve(address(market), nftDeafultPrice);
        bool buyResult = market.permitBuy{value: nftDeafultPrice}(nftOrder, signatureForWL, signatureForSellOrder, signatureForApprove);
        assertTrue(buyResult);
        vm.stopPrank();
    }
}