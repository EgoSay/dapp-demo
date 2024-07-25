
'use client'
import { useEffect, useState } from 'react';
import { getSlotInfo, getLength } from './getSlotInfo';
import logStyle from '../../styles/logs.module.css';

type LockInfo = {
  user: string;
  startTime: string;
  amount: number;
};

export default function Home() {
  const [locks, setLocks] = useState<any>([]);
  const [index, setIndex] = useState(0);
  const [length, setLength] = useState(0);

  useEffect(() => {
   
    let isMounted = true; // 控制递归调用的局部变量
    async function fetchLocks(currentIndex: number) {
      if (currentIndex == 0) {
        // 获取 _locks 的长度
        getLength().then( (len) => setLength(Number(BigInt(len))));
        console.log("length===> ", length)
      }
      const res: any = await getSlotInfo(currentIndex);
      if (isMounted && currentIndex < length) {
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
  }, [length, index]);

  return (
    <div className={logStyle.container}>
      <h1>Get Lock Info</h1>
      {locks.length === 0 ? (
        <p>Loading...</p>
      ) : (
        <div className={logStyle.container}>
          <h1>共有Locks: <strong> {length} </strong></h1>
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