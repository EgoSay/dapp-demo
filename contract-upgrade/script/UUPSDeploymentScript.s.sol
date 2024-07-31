// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MyERC20.sol";
import "../src/TokenFactoryV1.sol";
import "../src/TokenFactoryV2.sol";

contract UUPSDeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
         console.log("deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 步骤 1: 部署 ERC20 实现合约
        MyERC20 erc20Implementation = new MyERC20("", 0, 0);
        console.log("ERC20 Implementation deployed at:", address(erc20Implementation));

        // 步骤 2: 部署 Factory V1 实现合约
        TokenFactoryV1 factoryV1Implementation = new TokenFactoryV1();
        console.log("Factory V1 Implementation deployed at:", address(factoryV1Implementation));

        // 步骤 3: 部署 UUPS 代理，指向 Factory V1
        bytes memory initData = abi.encodeWithSelector(TokenFactoryV1.initialize.selector);
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryV1Implementation),
            initData
        );
        console.log("Factory Proxy (UUPS) deployed at:", address(factoryProxy));

        // 步骤 4: 使用 Factory V1 创建 ERC20 token
        TokenFactoryV1 factory = TokenFactoryV1(address(factoryProxy));
        address newToken = factory.deployInscription("TEST", 1000000 * 10**16, 10 * 10**16);
        console.log("New ERC20 token deployed at:", newToken);

        // 步骤 5: 铸造一些 token
        factory.mintInscription(newToken);
        console.log("Tokens minted");

        // 步骤 6: 部署 Factory V2 实现合约
        TokenFactoryV2 factoryV2Implementation = new TokenFactoryV2();
        console.log("Factory V2 Implementation deployed at:", address(factoryV2Implementation));

        // 步骤 7: 升级代理到 V2
        TokenFactoryV1(address(factoryProxy)).upgradeToAndCall(
            address(factoryV2Implementation),
            ""  // 如果需要初始化逻辑，可以在这里添加
        );
        console.log("Proxy upgraded to V2");

        // 步骤 8: 设置 ERC20 实现合约地址
        TokenFactoryV2(address(factoryProxy)).setImplementation(address(erc20Implementation));
        console.log("ERC20 implementation set in Factory V2");

        // 步骤 9: 使用升级后的 Factory V2 创建新的 ERC20 token
        TokenFactoryV2 factoryV2 = TokenFactoryV2(address(factoryProxy));
        address newTokenV2 = factoryV2.deployInscription("TEST2", 2000000 * 10 ** 16, 20 * 10 ** 17, 1 wei);
        console.log("New ERC20 token (V2) deployed at:", newTokenV2);

        // 步骤 10: 铸造一些新的 token（需要支付费用）
        // factoryV2.mintInscription{value: 0.00002 ether}(newTokenV2);
        // console.log("Tokens minted with V2 (paid)");

        vm.stopBroadcast();
    }
}