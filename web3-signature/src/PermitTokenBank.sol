// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Permit, ERC20}  from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";


library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

contract PermitTokenBank {

    ERC20Permit token ;
    address private owner;

    using SafeMath for uint256;

    // Mapping to track the balance of each depositor
    mapping (address => uint) balances;

    constructor(address tokenAddr) {
        token = ERC20Permit(tokenAddr);
    }

    // Event to log deposits
    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Banlances(address  indexed user, uint256 amount);

    // Event to log withdraw
    event Withdraw(address indexed user, uint256 bankBalance, uint256 adminBanlance);

    modifier checkAmount(uint256 amount) {
        require (amount > 0, "amount must be greater than 0");
        _;
    }

    // transfer user token to the bank
    function deposit(uint256 amount) public virtual checkAmount(amount) {
        require (amount <= token.balanceOf(msg.sender), "Insufficient balance");
        // require 保证转账安全性
        require(token.transferFrom(msg.sender, address(this), amount), "TOKEN_TRANSFER_OUT_FAILED");
        balances[msg.sender] = balances[msg.sender].add(amount);
        emit Deposit(msg.sender, address(this), amount);
        emit Banlances(msg.sender, balances[msg.sender]);
    }

    // withdraw amount token to the user wallet
    function withdraw(uint256 amount) external checkAmount(amount) {
        // check bank has enough token
        require (balances[msg.sender] >= amount, "Bank balance must be greater than withdraw amount");
        // require 保证转账安全性
        require(token.transfer(msg.sender, amount), "withdraw failed");
        balances[msg.sender] = balances[msg.sender].sub(amount);
        emit Withdraw(msg.sender, balances[msg.sender], amount);
    }

    // get user balance
    function getUserBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // the callback receives the token and records it
    function onTransferReceived(address to, uint256 amount) external checkAmount(amount) returns (bool) {
        require(msg.sender == address(token), "invalid token address");
        balances[to] = balances[to].add(amount);
        emit Deposit(msg.sender, to, amount);
        emit Banlances(to, balances[msg.sender]);
        return true;
    }

    function permitDeposit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) virtual checkAmount(amount) public {
      require (amount <= token.balanceOf(msg.sender), "Insufficient balance");
      // permit 签名
      token.permit(msg.sender, address(this), amount, deadline, v, r, s);
      require(token.transferFrom(msg.sender, address(this), amount), "TOKEN_TRANSFER_OUT_FAILED");
      balances[msg.sender] = balances[msg.sender].add(amount);
      emit Deposit(msg.sender, address(this), amount);
      emit Banlances(msg.sender, balances[msg.sender]);
    }
}