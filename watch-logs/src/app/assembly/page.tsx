
'use client'
import { useEffect, useState } from 'react';
import { getSlotInfo } from './getSlotInfo';
import logStyle from '../../styles/logs.module.css';

type LockInfo = {
  user: string;
  startTime: string;
  amount: number;
};

export default function Home() {
  const [locks, setLocks] = useState<any>([]);
  const [index, setIndex] = useState(0);

  useEffect(() => {
    let isMounted = true; // 控制递归调用的局部变量
    async function fetchLocks(currentIndex: number) {
      const res: any = await getSlotInfo(currentIndex);
      if (isMounted && res !== null) {
        setLocks((prevLocks:any) => {
          return [...prevLocks, res];
        });
        setIndex((prevIndex) => prevIndex + 1); // 更新索引
      }
    }

    fetchLocks(index);
    return () => {
      isMounted = false; // 组件卸载时停止递归调用
    };
  }, [index]);

  return (
    <div>
      <h1>Lock Info</h1>
      {locks.length === 0 ? (
        <p>Loading...</p>
      ) : (
        <div className={logStyle.container}>
          <ul className={logStyle.resultList}>
            {locks && locks.map((lock: any, index: number) => (
              <li key={index} className={logStyle.resultItem2}>
                <p>locks: <strong>{index}</strong></p>
                <p>user: <strong>{lock.user}</strong></p>
                <p>startTime:<strong>{lock.startTime}</strong></p>
                <p>amount: <strong>{lock.amount}</strong></p>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>


  );
}