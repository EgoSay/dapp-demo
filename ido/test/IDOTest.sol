// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import {RNTToken} from "../src/RNTToken.sol";
import {MyIDO, MockIDO} from "../src/MyIDO.sol";

contract IDOTest is Test {

    RNTToken idoToken;
    MockIDO ido;
    

    address idoOwner = makeAddr("idoOwner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 initUserEther = 0.08 ether;
    

    function setUp() public {
        
        vm.startPrank(idoOwner);
        idoToken = new RNTToken();
        ido = new MockIDO(address(idoToken));
        idoToken.mint(address(ido), idoToken.totalSupply());
        vm.stopPrank();
    }

    function testPreSaleSuccess() public {
        console.log(unicode">>>>> ===========================  测试预售成功 ===========================<<<<<<");
        // 测试用户参与预售
        vm.warp(ido.preSaleStartTime());
        vm.deal(alice, initUserEther);
        vm.startPrank(alice);
        ido.preSale{value: alice.balance}();
        assertEq(ido.getPreSaleAmount(), initUserEther);
        
        // 测试预售成功， 用户领取奖励
        vm.deal(alice, ido.preSaleTarget());
        ido.setTestTotalReceivedETH{value: ido.preSaleTarget()}(ido.preSaleTarget());
        vm.warp(ido.preSaleEndTime() + 1 hours);
        ido.claim();
        // 用户得到的奖励代币数额是否正确
        assertEq(idoToken.balanceOf(alice), initUserEther / ido.preSalePrice());
        vm.stopPrank();

        // 测试项目方提现
        vm.startPrank(idoOwner);
        ido.withdraw();
        // 项目方提现余额是否正确
        assertEq(idoOwner.balance, ido.preSaleTarget() * ido.projectCanWithdrawRate() / 100);
        vm.stopPrank();
    }

    // 测试未到预售开始时间
    function testPreSaleNotStart() public {
        console.log(unicode">>>>>=========================== 测试未到预售开始时间 ===========================<<<<<<");
        vm.warp(ido.preSaleStartTime() - 1 hours);
        vm.deal(alice, initUserEther);
        vm.startPrank(alice);
        vm.expectRevert("PreSale is not start");
        ido.preSale{value: alice.balance}();
        vm.stopPrank();

    }

    /**
     * 测试预售金额无效
     * 1. 单笔最小买入 0.01 eth
     * 2. 单笔最大买入 0.1 eth
     */
    function testInvalidAmountPreSale() public {
        console.log(unicode">>>>> =========================== 测试预售金额无效 ===========================<<<<<<");
        vm.warp(ido.preSaleStartTime());
        vm.startPrank(alice);
        vm.deal(alice, ido.minPreSaleAmount() - 1);
        vm.expectRevert("PreSale: PURCHASE_AMOUNT_INVALID");
        ido.preSale{value: alice.balance}();
        vm.stopPrank();

        console.log("test user buy amount is invalid");
        vm.warp(ido.preSaleStartTime());
        vm.startPrank(bob);
        vm.deal(bob, ido.maxPreSaleAmount() + 1);
        vm.expectRevert("PreSale: PURCHASE_AMOUNT_INVALID");
        ido.preSale{value: bob.balance}();
        vm.stopPrank();
    }

    // 测试预售募集金额已达上限，预售结束
    function testPreSaleOverCap() public {
        console.log(unicode">>>>> =========================== 测试预售募集金额已达上限，预售结束 ===========================<<<<<<");
        
        vm.warp(ido.preSaleStartTime() + 1 hours);
        vm.deal(alice, ido.preSaleCap());
        vm.prank(alice);
        ido.setTestTotalReceivedETH{value: ido.preSaleCap()}(ido.preSaleCap());

        address user = makeAddr("testPreSaleOverCap");
        vm.startPrank(user);
        vm.deal(user, initUserEther);
        vm.expectRevert("PreSale is full");
        ido.preSale{value: user.balance}();
        vm.stopPrank();
    }

    // 测试预售失败，用户退款
    function testReFund() public {
        console.log(unicode">>>>> =========================== 测试预售失败，用户退款 ===========================<<<<<<");
        address user = makeAddr("testReFund");
        vm.warp(ido.preSaleStartTime());
        vm.startPrank(user);
        vm.deal(user, initUserEther);
        ido.preSale{value: user.balance}();

        vm.warp(ido.preSaleEndTime() + 1 hours);
        ido.refund();
        assertEq(user.balance, initUserEther);
        vm.stopPrank();
    }
}