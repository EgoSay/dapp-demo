## Task

>编写 IDO 合约，实现 Token 预售，需要实现如下功能：
>- 开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
>- 任意用户可支付ETH参与预售；
>- 预售结束后，如果没有达到募集目标，则用户可领会退款；
>- 预售成功，用户可领取 Token，且项目方可提现募集的ETH

### 实现代码
[MyIDO.sol](../src/MyIDO.sol)


### 测试代码
[IDOTest.sol](../test/IDOTest.sol)

### 测试结果
[IDOTest.log](../test/logs/IDOTest.log)