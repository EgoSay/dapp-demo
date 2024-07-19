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

测试用例: [PermitNFTMarket.t.sol](./test/PermitNFTMarket.t.sol)

测试结果: 
[testPermitDeposit.log](./test/testPermitDeposit.log)
