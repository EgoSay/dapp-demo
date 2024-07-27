// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import {RNTToken, ECDSA} from "../src/RNTToken.sol";
import {EsRNTToken} from "../src/EsRNT.sol";
import {StakePool} from "../src/StakePool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakePoolTest is Test {
    RNTToken rnt;
    EsRNTToken esRnt;
    StakePool stakePool;

    uint256 private ALICE_PK = 0xA1111;
    address alice = vm.addr(ALICE_PK);

    function setUp() public {

        rnt = new RNTToken();
        esRnt = new EsRNTToken(address(rnt));
        stakePool = new StakePool(address(rnt), address(rnt));

        rnt.mint(alice, 1000 * 1e18);
    }

    function testStake() public {
        vm.startPrank(alice);
        rnt.approve(address(stakePool), type(uint256).max);

        // test stake
        stakePool.stake(100 * 1e18);
        vm.warp(block.timestamp + 1 days); 

        stakePool.stake(100 * 1e18);
        vm.warp(block.timestamp + 1 days);

        stakePool.stake(100 * 1e18);
        vm.warp(block.timestamp + 1 days);

        (uint256 stakedAmount, uint256 reward) = stakePool.getStakeDetails(alice);
        assertEq(stakedAmount, 300 * 1e18);
        uint256  expectReward = 100 * 1e18 * 3 + 100 * 1e18 * 2 + 100 * 1e18 * 1;
        assertEq(reward, expectReward);
        vm.stopPrank();
    }


    function testStakeWithPermit() public {
        uint256 nonce = rnt.nonces(alice);
        uint256 deadline = block.timestamp + 1 days;
        // 签名
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                rnt.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    rnt.getPermitTypehash(),
                    alice,
                    address(stakePool),
                    100 * 1e18,
                    nonce,
                    deadline
                ))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PK, digest);

        // test stake
        vm.startPrank(alice);
        stakePool.stakeWithPermit(100 * 1e18, deadline, v, r, s);
        vm.warp(block.timestamp + 3 days); 

        (uint256 stakedAmount, uint256 reward) = stakePool.getStakeDetails(alice);
        assertEq(stakedAmount, 100 * 1e18);
        assertEq(reward, 100 * 1e18 * 3);
        vm.stopPrank();
    }

    function testUnstake() public {
        
    }

    function testClaim() public {

    }
}

