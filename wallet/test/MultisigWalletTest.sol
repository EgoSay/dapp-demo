// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    MultisigWallet wallet;
    address[] public owners;
    uint256 public constant REQUIRED = 2;

    address public owner1 = address(1);
    address public owner2 = address(2);
    address public owner3 = address(3);
    address public non_owner = address(4);

    function setUp() public {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultisigWallet(owners, REQUIRED);
        assertEq(wallet.required(), REQUIRED);
    }

    
    function testSubmitAndConfirmTransaction() public {
        address testUser = makeAddr("test");
        // test submitTransaction
        vm.prank(owner1);
        uint txId = wallet.submitTransaction(testUser, 1 ether, "");
        assertEq(wallet.transactionCount(), 1);

        (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations) = wallet.transactions(txId);
        assertEq(to, testUser);
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertFalse(executed);
        assertEq(confirmations, 0);

        // test confirmTransaction
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner3);
        wallet.confirmTransaction(txId);
        (,,,, uint256 confirmations2) = wallet.transactions(txId);
        assertEq(confirmations2, 2);
        assertTrue(wallet.confirmations(txId, owner2));
        assertTrue(wallet.confirmations(txId, owner3));
    }

    // test executeTransaction
    function testExecuteTransaction(uint256 amount) public {
        vm.assume(amount >= 1 ether && amount <= 10 ether);
        address testUser = makeAddr("test2");
        vm.prank(owner1);
        uint txId = wallet.submitTransaction(testUser, amount, "");
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner3);
        wallet.confirmTransaction(txId);

        deal(address(wallet), amount * 2);
        wallet.executeTransaction(txId);
        assertEq(address(wallet).balance, amount);
        assertEq(testUser.balance, amount);

        (,,, bool executed,) = wallet.transactions(txId);
        assertTrue(executed);
    }

     // test failed transaction
    function testRevertTransaction() public {
        // test not owner subm
        address testUser = makeAddr("test3");
        vm.prank(non_owner);
        vm.expectRevert("Not an owner");
        wallet.submitTransaction(testUser, 1 ether, "");

        //  test duplicate confirm
        vm.prank(owner1);
        uint txId = wallet.submitTransaction(testUser, 1 ether, "");
        vm.startPrank(owner2);
        wallet.confirmTransaction(txId);
        vm.expectRevert("Transaction already confirmed");
        wallet.confirmTransaction(txId);
        vm.stopPrank();

        // test executeTransaction without enough confirmations
        vm.expectRevert("Not enough confirmations");
        wallet.executeTransaction(txId);    
    }

    // test add and remove owner
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    function testAddAndRemoveOwner() public {
        address newOwner = makeAddr("newOwner");
        vm.startPrank(owner1);
        vm.expectEmit(true, false, false, false);
        emit OwnerAdded(newOwner);
        wallet.addOwner(newOwner);
        assertTrue(wallet.ownerRoles(newOwner));

        vm.expectEmit(true, false, false, false);
        emit OwnerRemoved(owner2);
        wallet.removeOwner(owner2);
        assertFalse(wallet.ownerRoles(owner2));
        vm.stopPrank();
    }

}