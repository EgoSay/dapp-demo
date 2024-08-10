## TokenBank 测试
> 要求: 修改 TokenBank 存款合约 ,添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款。

代码链接: [PermitTokenBank](./src/PermitTokenBank.sol)

 [Token 存款测试用例](./test/PermitToken.t.sol)

 测试结果
![Token 存款测试结果](./resources/TokenBankDepositTest.png)

## NTFMarket 测试
> 要求: 添加功能 permitBuy() 实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架）
> 
> 白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 permitBuy() 函数，在permitBuy()中判断时候是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert

代码链接: 

[PermitNFTMarket](./src/PermitNFTMarket.sol)

测试用例: [PermitNFTMarketTest](./test/PermitNFTMarketTest.sol)

测试结果: 
[testPermitBuy.log](./test/testPermitBuy.log)


## MerkleTree 测试
实现一个 AirdopMerkleNFTMarket 合约(假定 Token、NFT、AirdopMerkleNFTMarket 都是同一个开发者开发)，功能如下：

基于 Merkel 树验证某用户是否在白名单中
在白名单中的用户可以使用上架（和之前的上架逻辑一致）指定价格的优惠 50% 的Token 来购买 NFT， Token 需支持 permit 授权。
要求使用 multicall( delegateCall 方式) 一次性调用两个方法：

- `permitPrePay()` : 调用token的 permit 进行授权
- `claimNFT()` : 通过默克尔树验证白名单，并利用 permitPrePay 的授权，转入 token 转出 NFT 

### 实现代码
[PermitAirdopMerkleNFTMarket](./src/PermitAirdopMerkleNFTMarket.sol)

### 测试用例
[PermitAirdopMerkleNFTMarketTest](./test/PermitAirdopMerkleNFTMarketTest.sol)

### 测试结果
[testPermitAirdopMerkleNFTMarket.log](./test/testPermitAirdopMerkleNFTMarket.log)
