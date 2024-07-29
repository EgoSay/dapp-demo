// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import {console, StdCheats, Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {TokenFactoryV1} from "../src/TokenFactoryV1.sol";
import {TokenFactoryV2} from "../src/TokenFactoryV2.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract TokenFactoryTest is Test {

    TokenFactoryV1 factoryV1Implementation;
    TokenFactoryV2 factoryV2Implementation;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    string  symbol = "TEST";
    uint256 totalSupply = 1000000 * 10**18;
    uint256 perMint = 1000 * 10**18;

    ERC1967Proxy proxy;


    function setUp() public {
        vm.startPrank(owner);
        factoryV1Implementation = new TokenFactoryV1();
        // factoryV1.initialize();

        // bytes memory initData = abi.encodeWithSelector(TokenFactoryV1.initialize.selector);
        // proxy = new ERC1967Proxy(address(factoryV1), initData);
        
        factoryV2Implementation = new TokenFactoryV2();
        // factoryV2.initialize();
        vm.stopPrank();

        console.log(owner, alice, bob);
    }

    function testDeployAndMintV1() public {
        vm.startPrank(alice);
        TokenFactoryV1 factory = TokenFactoryV1(address(proxy));
        address tokenAddr = factory.deployInscription(symbol, totalSupply, perMint);
        assertEq(factory.tokenCreator(tokenAddr), alice);
        assertEq(MyERC20(tokenAddr).symbol(), symbol);
        assertEq(MyERC20(tokenAddr).totalSupplyLimit(), totalSupply);

        factory.mintInscription(tokenAddr);
        MyERC20 token = MyERC20(tokenAddr);
        assertEq(token.balanceOf(alice), perMint);
        vm.stopPrank();

    }

    function testUpgradeAndStatePreservation() public {
        
        // set proxy, use alice
        vm.startPrank(alice);
        bytes memory initData = abi.encodeWithSelector(TokenFactoryV1.initialize.selector);
        proxy = new ERC1967Proxy(address(factoryV1Implementation), initData);
        vm.stopPrank();

        // Deploy a token with V1, user bob
        vm.startPrank(bob);
        TokenFactoryV1 factoryV1 = TokenFactoryV1(address(proxy));
        console.log("fcatory v1 owner: ", factoryV1.owner());
        address tokenV1 = factoryV1.deployInscription(symbol, totalSupply, perMint);
        vm.stopPrank();

        // Upgrade to V2, user alice
        vm.startPrank(alice);
        TokenFactoryV1(address(proxy)).upgradeToAndCall(address(factoryV2Implementation), "");


        // user v2 deploy a new token
        TokenFactoryV2 factoryV2 = TokenFactoryV2(address(proxy));
        factoryV2.setImplementation(tokenV1);
        address tokenV2 = factoryV2.deployInscription(symbol, totalSupply * 2, perMint * 2, 1 ether);

        // Verify state preservation, the token owner need be bob
        assertEq(factoryV2.tokenCreator(tokenV1), bob);
        assertEq(factoryV2.tokenCreator(tokenV2), alice);
        assertEq(MyERC20(tokenV1).totalSupplyLimit(), totalSupply);
        assertEq(MyERC20(tokenV2).totalSupplyLimit(), totalSupply * 2);
        assertEq(MyERC20(tokenV1).perMint(), perMint);
        assertEq(MyERC20(tokenV2).perMint(), perMint * 2);

        // Try to mint with V1 (should fail due to lack of permission)
        vm.expectRevert("Not the token creator");
        factoryV2.mintInscription(tokenV1);

        // Try to mint with V2 (should fail due to lack of payment)
        vm.expectRevert("Insufficient payment");
        factoryV2.mintInscription(tokenV2);
        // vm.stopPrank();
    
        // Give some ETH
        // vm.startPrank(address(proxy));
        uint256 payedFees = perMint * 2 * 1 ether;
        vm.deal(alice, payedFees); 
        factoryV2.mintInscription{value: payedFees}(tokenV2);
        assertEq(MyERC20(tokenV2).balanceOf(alice), perMint * 2);
        vm.stopPrank();
    }


}