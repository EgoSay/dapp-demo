/*
 * @Author: Joe_Chan 
 * @Date: 2024-07-18 11:25:24
 * @Description: 
 */
'use client'
import React, { useEffect, useState } from 'react';
import { createPublicClient, http, parseAbiItem } from 'viem'
import logStyle from '../styles/logs.module.css'

// USDC 合约地址（以太坊主网）
const USDT_CONTRACT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const TRANSFER_EVENT_ABI = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)');

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

  const [lastestBlockNumber, setBlockNumber] = useState<any>();
  const [blockHash, setBlockHash] = useState<any>();
  const [transferLogs, setLogs] = useState<any>([]);

  
  
  useEffect(() => {
    console.log('>>>>>>>>>>> start');
    const fetchLatestBlockNumber = () => {
      client.watchBlocks({
        emitOnBegin: true,
        onBlock(block) {
            setBlockNumber(Number(block.number));
            setBlockHash(block.hash);
        }
    })
    };
    fetchLatestBlockNumber();

    const fetchLogs = () => {
      client.watchEvent({
        address: USDT_CONTRACT_ADDRESS,
        event: TRANSFER_EVENT_ABI,
        poll: true,
        pollingInterval: 1000,
        onLogs: (newLogs:any) => {
          console.log('newLogs', newLogs);
          // 处理 newLogs，将 BigInt 转换为字符串
          const processedLogs = newLogs.map((log:any) => ({
            blockNumber: Number(log.blockNumber).toString(),
            from: log.args.from,
            to: log.args.to,
            value: parseInt(log.args.value) / 1000000,
            transactionHash: log.transactionHash
          }));
          console.log('processedLogs', processedLogs);
          setLogs((prevLogs:any) => {
            const mergedLogs = [...processedLogs, ...prevLogs];
            const uniqueLogs = Array.from(new Set(mergedLogs.map(log => JSON.stringify(log)))).map(log => JSON.parse(log));
            console.log('uniqueLogs', uniqueLogs);
            return uniqueLogs;
          });
        },
      });
    };

    fetchLogs();

    // Cleanup function to clear any intervals if necessary
    return () => {
      // Here you might want to stop the polling if your client supports such a method
      // client.stopWatching();
    };
  }, []);

  return (
    <div className ={logStyle.container}>
        <h1 color='green'>当前区块: <strong>{Number(lastestBlockNumber)}</strong><br/>区块哈希: <strong>{blockHash}</strong></h1>
        <h1><strong> USDT Transfer 流水: </strong></h1>
        <ul className={logStyle.resultList}>
          {transferLogs && transferLogs.map((transfer:any, index:number) => (
            <li key={index} className={logStyle.resultItem}>
              <p>区块: <strong>{transfer.blockNumber}</strong></p>
              <p>交易ID:<strong>{transfer.transactionHash}</strong></p>
              <p>USDT: <strong>{transfer.value}</strong></p>
              <p>From: <strong>{transfer.from}</strong></p> 
              <p>To: <strong>{transfer.to}</strong></p>
            </li>
          ))}
        </ul>
    </div>
  );
}
