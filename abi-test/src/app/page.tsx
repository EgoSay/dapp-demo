'use client'
import React, { useState } from 'react';
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains';
import style from '../styles/style.module.css'

// USDC 合约地址（以太坊主网）
const USDC_CONTRACT_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

// 自定义一个 rpc 
const CUTOME_MAINNET = {
  id: 1,
  name: 'Ethereum',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: ['https://rpc.mevblocker.io'],
    },
  },
}

const client = createPublicClient({
  chain: CUTOME_MAINNET,
  transport: http(),
})



export default function Home() {

  const [blockNumber, setBlockNumber] = useState<any>('100');
  const [loading, setLoading] = useState<boolean>(false);
  const [transferLogs, setTransferLogs] = useState<any>();
  

  const fetchTransferLogs = async () => {
    setLoading(true);
    const latestBlock = await client.getBlockNumber();
    console.log(latestBlock)
    const floorBlock = latestBlock - BigInt(blockNumber);
    try {
      const logs = await client.getLogs({
        address: USDC_CONTRACT_ADDRESS,
        event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
        fromBlock: floorBlock,
        toBlock: latestBlock,
      })
      console.log(logs)
      setTransferLogs(logs)
    } catch (err) {
      console.error(err)
    }
    setLoading(false);
    
  }

  return (
    <div className ={style.container}>
        <h1>查询 Ethereum USDC 转账记录</h1>
        <input className={style.input}
          type="text"
          value={blockNumber}
          onChange={(e) => setBlockNumber(e.target.value)}
          placeholder="Enter block number"
        />
        <button className={style.button} onClick={fetchTransferLogs} disabled={loading}>
          {loading ? 'Loading...' : 'Fetch Transfer Logs'}
        </button> 
        共获取到:{transferLogs ? transferLogs.length : 0} 条日志
        <ul className={style.resultList}>
        {transferLogs && transferLogs.map((transfer:any, index:number) => (
          <li key={index} className={style.resultItem}>
            从 {transfer.args.from} 转账给 {transfer.args.to}  <br/> USDC: {Number(transfer.args.value)}  <br/> 交易ID: {transfer.transactionHash}
          </li>
        ))}
      </ul>
    </div>
  );
}
