// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";


contract PermitNFTMarket is EIP712 {
    using ECDSA for bytes32;
    // define nft sale info
    struct nftTokens {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
    }

    // Mapping to track the nft type to nftTokens
    mapping(address => mapping(uint256 => nftTokens)) nftSaleMap;
    // 存储 nft 售卖情况
    mapping(bytes32 => bool) filledOrders;
    // 项目方，也就是白名单签署方
    address public whitelistSigner;

    bytes32 public constant LISTING_TYPEHASH =
        keccak256("PermitNFTMarketList(address seller,address nftContract,uint256 tokenId,uint256 price)");
    bytes32 public constant WL_TYPEHASH =
        keccak256("PermitNFTWhiteList(address wlSigner, address user)");

    // event to log nft trade record
    event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event NFTBought(address indexed buyer, address indexed nftContract, uint256 indexed tokenId);

    // my ERC20 token contract address
    IERC20 private paymentTokenAddr;
    ERC20Permit private permitToken;

    constructor(address _permitTokenAddr, address _whitelistSigner) EIP712("PermitNFTMarket", "version 1") {
        permitToken = ERC20Permit(_permitTokenAddr);
        whitelistSigner = _whitelistSigner;
    }

    // add nft to the market list
    function list(address nftContract, uint256 tokenId, uint256 price) external returns (bool) {
        // TODO nft owner 需要签名，授权 nftMarket 上架 nft 信息
        require(price > 0, "nft price must greater than 0");
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(msg.sender == owner, "not nft owner");

        // transfer nft and list
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        nftSaleMap[nftContract][tokenId] = nftTokens({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price
        });
        emit NFTListed(msg.sender, nftContract, tokenId, price);
        return true;
    }

    // buy nft from the market
    function buyNFT(address nftContract, uint256 tokenId) public returns (bool) {
        nftTokens memory nftInfo = nftSaleMap[nftContract][tokenId];
        uint256 balance = permitToken.balanceOf(msg.sender);
        require(balance >= nftInfo.price, " have no enough balance");
        // transfer erc20 token to the seller
        permitToken.transferFrom(msg.sender, nftInfo.seller, nftInfo.price);
        // erc721 transfer nft to the buyer
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        // delist nft from the market
        delete nftSaleMap[nftContract][tokenId];
        emit NFTBought(msg.sender, nftContract, tokenId);
        return true;
    }

    function getNFTPrice(address nftContract, uint256 tokenId) public view returns (uint256) {
        nftTokens memory nftInfo = nftSaleMap[nftContract][tokenId];
        return nftInfo.price;
    }

    function onTransferReceived(address buyer, uint256 amount, bytes calldata data) external returns (bool) {
        // decode calldata and get nftContract address and tokenId
        address nftContract;
        uint256 tokenId;
        (nftContract, tokenId) = decodeNFTInfo(data);
        uint256 price = getNFTPrice(nftContract, tokenId);
        require(amount >= price, "have no enough token");
        paymentTokenAddr.transfer(nftSaleMap[nftContract][tokenId].seller, amount);

        // erc721 transfer nft to the buyer
        IERC721(nftContract).transferFrom(address(this), buyer, tokenId);
        
        // delist nft from the market
        delete nftSaleMap[nftContract][tokenId];
        emit NFTBought(buyer, nftContract, tokenId);
        return true;
    }

    // check if EOA
    function isContract(address user) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(user)
        }
        // eoa account have no codeHash
        return size > 0;
    }

    function decodeNFTInfo(bytes calldata data) public pure returns (address, uint256) {
        // 使用 abi.decode 从 data 中解析出 address 和 uint256
        (address addr, uint256 value) = abi.decode(data, (address, uint256));
        return (addr, value);
    }

    function permitBuy(
        address nftContract,
        uint256 tokenId,
        uint256 deadline,
        bytes calldata signatureForWL,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove
    ) public returns (bool) {
        nftTokens memory nftInfo = nftSaleMap[nftContract][tokenId];

        verifySignature(nftInfo, nftContract, signatureForWL, signatureForSellOrder);

        handlePurchase(nftInfo, nftContract, deadline, signatureForApprove);
        
        return true;

    }

    function verifySignature (
        nftTokens memory nftInfo,
        address nftContract,
        bytes calldata signatureForWL,
        bytes calldata signatureForSellOrder
    ) private {
        // 检查白名单签名
        bytes32 wlDigest = _hashTypedDataV4(
            keccak256(abi.encode(WL_TYPEHASH, whitelistSigner, address(msg.sender)))
        );
       
        address wlSigner = ECDSA.recover(wlDigest, signatureForWL);
        require(wlSigner == whitelistSigner, "You are not in WL");
        console.log("wl  check is ok");

        // 检查上架信息是否存在， [检查后为了防止重入，删除上架信息]
        require(nftInfo.seller != address(0), "nft not on sale");
        delete nftSaleMap[nftContract][nftInfo.tokenId];
        
        // 检查 nft 上架信息是否来自 nft owner 的签名授权
        bytes32 orderHash = _hashTypedDataV4(
            keccak256(abi.encode(LISTING_TYPEHASH, nftInfo.seller, nftInfo.nftContract, nftInfo.tokenId, nftInfo.price))
        );
        // console.logBytes32(orderHash);
        require(filledOrders[orderHash] == false, "Order already filled");
        filledOrders[orderHash]=true;
        address nftOwner= IERC721(nftContract).ownerOf(nftInfo.tokenId);
        address orderSeller = ECDSA.recover(orderHash, signatureForSellOrder);
        // console.log(orderSeller);
        require(orderSeller != nftOwner, "nft seller not the nft owner");
        console.log("order check is ok");
    }

     function handlePurchase(
        nftTokens memory nftInfo,
        address nftContract,
        uint256 deadline,
        bytes memory signatureForApprove) private {
        // 执行 ERC20 的 permit 进行 授权
        bytes32 r;
        bytes32 s;
        uint8 v;
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(signatureForApprove, 32))
            s := mload(add(signatureForApprove, 64))
            v := byte(0, mload(add(signatureForApprove, 96)))
        }
        permitToken.permit(msg.sender, address(this), nftInfo.price, deadline, v, r, s);
        
        // 执行 ERCE2O 的转账
        require(permitToken.transferFrom(msg.sender, nftInfo.seller, nftInfo.price), "TOKEN_TRANSFER_OUT_FAILED");
        console.log("token transfer is ok");
        // 执行 NFT 的转账
        IERC721(nftContract).transferFrom(address(this), msg.sender, nftInfo.tokenId);
        emit NFTBought(msg.sender, nftContract, nftInfo.tokenId);

     }
     
     function getHashData(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }


}