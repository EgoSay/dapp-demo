// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";


contract MyIDO is Ownable(msg.sender){

    IERC20 public token;
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    // 预售价格
    uint256 public constant preSalePrice = 0.0001 ether;
    uint256 public constant preSaleTotal = 100_0000;
    // limit user min and max preSale amount
    uint256 public immutable maxPreSaleAmount = 0.1 ether;
    uint256 public immutable minPreSaleAmount = 0.01 ether;
    // 预售目标
    uint256 public immutable preSaleTarget = 100 ether;
    // 预售超募上限
    uint256 public immutable preSaleCap = 200 ether;

    // 预售开始时间, "2024-07-23 00:00:00"
    uint256 public preSaleStartTime = 1721664000;
    // 预售结束时间
    uint256 public preSaleEndTime = preSaleStartTime + 7 days;
    // 预售已募集金额
    // uint256 public preSaleRaised;
    // 预售成功后，项目方可提现比例 => 10 %
    uint256 public projectCanWithdrawRate = 10;

    // 预售参与用户及其参与数量
    mapping(address => uint256) public preSaleParticipantAmount;
   
    modifier isOnPreSale() {
        require(block.timestamp >= preSaleStartTime && block.timestamp <= preSaleEndTime, "PreSale is not start");
        require(address(this).balance <= preSaleCap, "PreSale is full");
        _;
    }
    modifier OnlySuccess() {
        require(block.timestamp > preSaleEndTime, "PreSale is not end");
        require(address(this).balance >= preSaleTarget, "PreSale is not enough");
        _;
    }

    modifier OnlyFailed() {
        require(block.timestamp > preSaleEndTime, "PreSale is not end");
        require(address(this).balance < preSaleTarget, "PreSale is success");
        _;
    }

    /*
     * 开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长
     * 任意用户可支付ETH参与预售
     * @param amount 用户计划参与预售的数量
     */
    function preSale() public isOnPreSale() payable {
        require(msg.value >= minPreSaleAmount && msg.value <= maxPreSaleAmount, "PreSale: PURCHASE_AMOUNT_INVALID");
        require(msg.value <= (preSaleCap - address(this).balance), "PreSale is full");

        // update preSaleParticipantAmount
        preSaleParticipantAmount[msg.sender] += msg.value;
        emit PreSale(msg.sender, msg.value);
    }


    /**
     * 预售结束后，如果没有达到募集目标，则用户可退款
     */

    function refund() public OnlyFailed() {
        address refunder = msg.sender;
        require(preSaleParticipantAmount[refunder] > 0, "No refund");
        (bool success,) = refunder.call{value: preSaleParticipantAmount[refunder]}("");
        require(success, "Refund: FAILED");
        emit Refund(refunder, preSaleParticipantAmount[refunder]);
        preSaleParticipantAmount[refunder] = 0;
    }

    /**
     * 预售成功，用户可领取 Token
     */
    function claim() public OnlySuccess() {
        require(preSaleParticipantAmount[msg.sender] > 0, "No claim");
        uint256 canClaimAmount = preSaleParticipantAmount[msg.sender] * preSaleTotal / (address(this).balance);
        preSaleParticipantAmount[msg.sender] = 0;
        token.transfer(msg.sender, canClaimAmount);
        emit Claim(msg.sender, canClaimAmount);
    }

    /**
     * 预售成功，项目方可提现募集的ETH
     */
    function withdraw() public OnlySuccess() {
        // 项目方只能提取一定比例的募集金额
        uint256 preSaleRaised = address(this).balance;
        uint256 projectCanWithdraw = preSaleRaised * projectCanWithdrawRate / 100;
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
