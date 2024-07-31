# 合约升级

## Task1
实现⼀个可升级的工厂合约，工厂合约有两个方法：

- `deployInscription(string symbol, uint totalSupply, uint perMint)` ，该方法用来创建 ERC20 token，（模拟铭文的 deploy）， symbol 表示 Token 的名称，totalSupply 表示可发行的数量，perMint 用来控制每次发行的数量，用于控制mintInscription函数每次发行的数量

- `mintInscription(address tokenAddr)` 用来发行 ERC20 token，每次调用一次，发行perMint指定的数量。

要求：

- 合约的第⼀版本用普通的 new 的方式发行 ERC20 token 。

- 第⼆版本，deployInscription 加入一个价格参数 price  deployInscription(string symbol, uint totalSupply, uint perMint, uint price) , price 表示发行每个 token 需要支付的费用，并且 第⼆版本使用最小代理的方式以更节约 gas 的方式来创建 ERC20 token，需要同时修改 mintInscription 的实现以便收取每次发行的费用

### 实现代码:
- [TokenFactoryV1.sol](./src/TokenFactoryV1.sol)
- [TokenFactoryV2.sol](./src/TokenFactoryV2.sol)

### 测试用例
- [TokenFactoryTest.sol](./test/TokenFactoryTest.sol)

测试日志:
- [TokenFactoryTest.log](./test/TokenFactoryTest.log)

### 合约部署信息
  - 代理合约: https://sepolia.etherscan.io/address/0xfde330598359e46b758b0b42a634d8e697411b1e#code
  
  - TokenFactoryV1: https://sepolia.etherscan.io/address/0x066607AA549AF9E57625C2710cE72267C4A26044
  
  - TokenFactoryV2: https://sepolia.etherscan.io/address/0x4D43da276171AB682c50D4DeDDF7189a27a4E13F

  ```
  deployer: 0x8e9df9e6031C95Cac5974633D7aFdFc922027aa6

  ERC20 Implementation deployed at: 0x3e2982f7344622847eB96a3CF478C2e8F8D6DED5

  Factory V1 Implementation deployed at: 0x066607AA549AF9E57625C2710cE72267C4A26044

  Factory Proxy (UUPS) deployed at: 0xfDE330598359E46b758B0B42A634d8e697411B1E

  New ERC20 token deployed at: 0xb80cEb8c75c839290027D6e0CedA55188E2B3555

  Factory V2 Implementation deployed at: 0x4D43da276171AB682c50D4DeDDF7189a27a4E13F
  
  New ERC20 token (V2) deployed at: 0x7c9e30b50A6d9C52662319B86F0cE50BC8f34634
  ```


