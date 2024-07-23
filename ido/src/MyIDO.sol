// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract MyIDO is Ownable(msg.sender){

    IERC20 public token;
    
    // 预售价格
    uint256 public immutable preSalePrice = 0.0001 ether;
    // limit user min and max preSale amount
    uint256 public immutable maxPreSaleAmount = 1000;
    uint256 public immutable minPreSaleAmount = 100;
    // 预售目标
    uint256 public immutable preSaleTarget = 100 ether;
    // 预售超募上限
    uint256 public immutable preSaleCap = 200 ether;

    // 预售开始时间, "2024-07-23 00:00:00"
    uint256 public preSaleStartTime = 1721664000;
    // 预售结束时间
    uint256 public preSaleEndTime = preSaleStartTime + 7 days;
    // 预售已募集金额
    uint256 public preSaleRaised;

    // 预售参与用户及其参与数量
    mapping(address => uint256) public preSaleParticipantAmount;
   
    modifier isOnPreSale() {
        require(block.timestamp >= preSaleStartTime && block.timestamp <= preSaleEndTime, "PreSale is not start");
        require(preSaleRaised <= preSaleCap, "PreSale is full");
        _;
    }
    modifier OnlySuccess() {
        require(block.timestamp > preSaleEndTime, "PreSale is not end");
        require(preSaleRaised >= preSaleTarget, "PreSale is not enough");
        _;
    }

    modifier OnlyFailed() {
        require(block.timestamp > preSaleEndTime, "PreSale is not end");
        require(preSaleRaised < preSaleTarget, "PreSale is success");
        _;
    }

    /**
     * 开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长
     * 任意用户可支付ETH参与预售
     * @param amount 用户计划参与预售的数量
     */
    function preSale(uint256 amount) public isOnPreSale() payable {
        require(amount > minPreSaleAmount && amount <= maxPreSaleAmount, "PreSale: PURCHASE_AMOUNT_INVALID");
        uint256 amountToPay = amount * preSalePrice;
        // check user eth balance
        require(msg.value < amountToPay, "Insufficiant ETH");
        require(amountToPay <= (preSaleCap - preSaleRaised), "PreSale is full");
       
        // update preSaleRaised
        preSaleRaised += amountToPay;

        // update preSaleParticipantAmount
        preSaleParticipantAmount[msg.sender] += amountToPay;
        payable(address(this)).transfer(amountToPay);
        emit PreSale(msg.sender, amount);
    }


    /**
     * 预售结束后，如果没有达到募集目标，则用户可退款
     */

    function refund() public OnlyFailed() {
        address refunder = msg.sender;
        require(preSaleParticipantAmount[refunder] > 0, "No refund");
        payable(refunder).transfer(preSaleParticipantAmount[refunder]);
        preSaleParticipantAmount[refunder] = 0;
        emit Refund(refunder, preSaleParticipantAmount[refunder]);
    }

    /**
     * 预售成功，用户可领取 Token
     */
    function claim() public OnlySuccess() {
        require(preSaleParticipantAmount[msg.sender] > 0, "No claim");
        uint256 canClaimAmount = preSaleParticipantAmount[msg.sender] * 1e12 / (preSaleRaised * 1e12);
        preSaleParticipantAmount[msg.sender] = 0;
        token.transfer(msg.sender, canClaimAmount);
        emit Claim(msg.sender, canClaimAmount);
    }

    /**
     * 预售成功，用户可领取 Token，且项目方可提现募集的ETH
     */
    function withdraw() public OnlySuccess() {
        // 项目方只能提取一定比例的募集金额
        uint256 projectCanWithdraw = preSaleRaised * 1 / 10;
        payable(owner()).transfer(projectCanWithdraw);
        preSaleRaised -= projectCanWithdraw;
        emit Withdraw(msg.sender, projectCanWithdraw);
    }

    function getPreSaleAmount() public view returns (uint256) {
        return preSaleParticipantAmount[msg.sender];
    }

    event PreSale(address indexed user, uint256 amount);
    event Refund(address indexed refunder, uint256 amount);
    event Claim(address indexed claimer, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 amount);
}
