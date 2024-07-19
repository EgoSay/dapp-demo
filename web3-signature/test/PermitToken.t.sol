// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import {PermitERC20Token} from "../src/PermitERC20Token.sol";
import {PermitTokenBank} from "../src/PermitTokenBank.sol";


contract ERC20Test is Test {

    PermitERC20Token internal token;
    PermitTokenBank internal bank;

    uint256 internal ownerPrivateKey;
    uint256 internal spenderPrivateKey;

    address internal owner;
    address internal spender;

    function setUp() public {
        token = new PermitERC20Token();
        bank = new PermitTokenBank(address(token));

        ownerPrivateKey = 0x0A11CE;
        spenderPrivateKey = 0x0B0B;

        owner = vm.addr(ownerPrivateKey);
        spender = vm.addr(spenderPrivateKey);

        token.mint(owner, 1e18);
    }

    function testPermitDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1e18);
        
        
        vm.startPrank(owner);
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    token.getPermitTypehash(),
                    owner,
                    address(bank),
                    amount,
                    nonce,
                    deadline
                ))
            )
        );
        
        // 签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // 执行存款操作
        bank.permitDeposit(amount, deadline, v, r, s);
        // 检查TokenBank合约的余额和用户的存款
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(bank.getUserBalance(owner), amount);

        vm.stopPrank();
    }

}