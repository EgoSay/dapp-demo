// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import {RNTToken} from "../src/RNTToken.sol";
import {MyIDO} from "../src/MyIDO.sol";

contract IDOTest is Test {

    RNTToken idoToken;
    MyIDO ido;
    

    address idoOwner = makeAddr("idoOwner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 initUserEther = 888 ether;
    

    function setUp() public {
        
        vm.startPrank(idoOwner);
        idoToken = new RNTToken();
        ido = new MyIDO();
        vm.stopPrank();

        // deal user some ether
        vm.deal(alice, initUserEther);
        vm.deal(bob, initUserEther);
    }

    function testPreSale(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100_000);

        // 测试用户参与预售
        vm.startPrank(alice);
        ido.preSale(amount);
        uint256 payedEther = amount * ido.preSalePrice();
        assertEq(alice.balance, initUserEther - payedEther);
        assertEq(ido.getPreSaleAmount(), payedEther);
        vm.stopPrank();

        // 测试预售成功
        // vm.deal(account, newBalance);
        // vm.warp(newTimestamp);
        
    }
}