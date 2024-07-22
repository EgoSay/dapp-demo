// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20Permit, EIP712, ERC20, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract NFTMarketWithOrderSign is EIP712("NFTMarketWithOrderSign", "1"), Ownable(msg.sender), Nonces {
    using ECDSA for bytes32;

    // define nft sale info 
    struct NftOrderInfo {
        address seller;  // nft seller
        address nftContract; // nft contract address
        address payToken;  // pay token
        uint256 tokenId;  // nft token id
        uint256 price;  // nft price
        uint256 deadline;  // order deadline
    }

    // 用户下架 nft 时把签名存储，代表无效签名
    mapping(bytes => bool) invalidSignatures;

    

    // 项目方，也就是白名单签署方
    address public whitelistSigner;
    address public constant ETH_FLAG = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public feeTo;
    uint256 public constant feeBP = 30; // 30/10000 = 0.3%

    /*
     * @description: add nft to the market list
     * 不需要 list 上架操作了，只需要前端操作签名，生成签名，签名内容包括上架订单信息即可
     */    
    // function list(....) external returns (bool) {}


    /*
     * @description: cacel the nfs list order
     * @param {bytes32} orderId 
     */    
    function cancelOrder(bytes calldata signatureForSellOrder) external {
        invalidSignatures[signatureForSellOrder] = true;
        emit Cancel(signatureForSellOrder);
    }

    // buy with eth and no fee
    function buy(NftOrderInfo memory nftOrder) public payable {
        _buy(nftOrder, feeTo);
    }

    /*
     * @description: private buy operation
     * @param {bytes32} orderId  => abi.encode(NftOrderInfo)
     * @param {address} feeReceiver 
     * @return {*}
     */    
    function _buy(NftOrderInfo memory order, address feeReceiver) private {
        
        require(order.seller != address(0), "PermitNFTMarket: order not listed");
        require(order.deadline > block.timestamp, "PermitNFTMarket: order is expired");
        
        // 2. transfer nft to the buyer
        IERC721(order.nftContract).safeTransferFrom(order.seller, msg.sender, order.tokenId);
        console.log("transfer nft success");
        // 3. transfer fee to the fee receiver
        uint256 fee = feeReceiver == address(0) ? 0 : order.price * feeBP / 10000;
        // safe check
        if (order.payToken == ETH_FLAG) {
            console.log(msg.sender);
            console.log(order.price);
            console.log(msg.value);
            require(msg.value >= order.price, "PermitNFTMarket: wrong eth value");
        } else {
            require(msg.value == 0, "PermitNFTMarket: wrong eth value");
        }
        if (fee > 0) _transferOut(order.payToken, msg.sender, feeReceiver, fee);

        // transfer the rest to the seller
        uint256 sellPrice = order.price - fee;
        _transferOut(order.payToken, msg.sender, order.seller, sellPrice);
        emit NFTBought(msg.sender, order.nftContract, order.tokenId, order.price);
    }

    function _transferOut(address token, address from, address to, uint256 amount) private {
        if (token == ETH_FLAG) {
            // TODO 这样只能从 market 转 eth 到 seller, 而不是从 buyer 直接转账到 seller
            payable(to).transfer(amount);
        } else {
            IERC20(token).transferFrom(from, to, amount);
        }
    }


    function permitBuy(
        NftOrderInfo memory nftOrder,
        bytes calldata signatureForWL,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove
    ) public returns (bool) {        
        
        _verifyWL(signatureForWL);

          // nft owner 需要签名，授权 nftMarket 出售 nft 信息
        _nftPermit(nftOrder, signatureForSellOrder);

        _tokenPermit(nftOrder, signatureForApprove);

        _buy(nftOrder, address(0));
        
        return true;

    }

    bytes32 public constant WL_TYPEHASH =
        keccak256("PermitNFTWhiteList(address wlSigner, address user)");
    function _verifyWL (bytes calldata signatureForWL) view private {
        // 检查白名单签名
        bytes32 wlDigest = _hashTypedDataV4(
            keccak256(abi.encode(WL_TYPEHASH, whitelistSigner, address(msg.sender)))
        );
        address wlSigner = ECDSA.recover(wlDigest, signatureForWL);
        require(wlSigner == whitelistSigner, "You are not in WL");
        console.log("wl  check is ok");
    }


    // define nft sale order id
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "NftOrderInfo(address seller,address nftContract,address payToken,uint256 tokenId,uint256 price,uint256 deadline)");
    function _nftPermit(NftOrderInfo memory nftOrder, bytes calldata signatureForSellOrder) private {
        // 检查上架信息是否存在， [检查后为了防止重入，删除上架信息]
        require(nftOrder.seller != address(0), "nft not on sale");
        require(!invalidSignatures[signatureForSellOrder], "invalid signature");
        invalidSignatures[signatureForSellOrder] = true;

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(ORDER_TYPEHASH, 
                        nftOrder.seller, 
                        nftOrder.nftContract,
                        nftOrder.payToken, 
                        nftOrder.tokenId, 
                        nftOrder.price,
                        nftOrder.deadline))
        );
        address signer = ECDSA.recover(digest, signatureForSellOrder);
        require(signer == nftOrder.seller, "invalid nft permit signature");
    }


    bytes32 public constant PERMIT_TOKEN_TYPEHASH =
        keccak256("Permit(address owner,address spender,address paytoken,uint256 value,uint256 nonce,uint256 deadline)");
     function _tokenPermit(
        NftOrderInfo memory nftOrder,
        bytes memory signatureForApprove) private {
        // 执行 eth 转账的 permit 校验
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(PERMIT_TOKEN_TYPEHASH, 
                        msg.sender, 
                        address(this),
                        nftOrder.payToken, 
                        nftOrder.price,
                        _useNonce(msg.sender),
                        nftOrder.deadline))
        );
        address signer = ECDSA.recover(digest, signatureForApprove);
        require(signer == msg.sender, "invalid eth permit signature");
     }
     
    function getHashData(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    function decodeSign(bytes memory signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        return (r, s, v);
    }

    // admin functions
    function setWhiteListSigner(address signer) external onlyOwner {
        require(signer != address(0), "MKT: zero address");
        require(whitelistSigner != signer, "MKT:repeat set");
        whitelistSigner = signer;

        emit SetWhiteListSigner(signer);
    }

    function setFeeTo(address to) external onlyOwner {
        require(feeTo != to, "MKT:repeat set");
        feeTo = to;

        emit SetFeeTo(to);
    }

    event NFTBought(address indexed buyer, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event Cancel(bytes signatureForSellOrder);
    event SetFeeTo(address indexed feeReceiver);
    event SetWhiteListSigner(address indexed signer);

}