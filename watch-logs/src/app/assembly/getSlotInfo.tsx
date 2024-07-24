/*
 * @Author: Joe_Chan 
 * @Date: 2024-07-24 18:07:52
 * @Description: 
 */
// pages/api/getLockInfo.js
import { createPublicClient, http, toHex, keccak256 } from 'viem'
import { sepolia } from 'viem/chains'
 
const publicClient = createPublicClient({ 
  chain: sepolia, 
  transport: http(), 
}) 

const contractAddress = '0xB2B77A3c7600Aac203Bc1Bf7Cae12317efB3D508';
// 计算数组的起始槽 
const arrayStartSlot = keccak256('0x0000000000000000000000000000000000000000000000000000000000000000');

// struct LockInfo{
//     address user; 20 bytes
//     uint64 startTime; 8 bytes
//     uint256 amount;
// }
async function getLockInfo(index:any) {
  const baseSlot = BigInt(arrayStartSlot) + BigInt(index) * BigInt(2);
  console.log("===========baseSlot", index, baseSlot);

  // address user 和 uint64 startTime 可以共用一个 slot 32bytes
  const userAndStartTimeSlot = baseSlot;
  const amountSlot = baseSlot + BigInt(1);

  const userAndStartTimeSlotData = await publicClient.getStorageAt({
    address: contractAddress,
    slot: toHex(userAndStartTimeSlot),
  });

  if (userAndStartTimeSlotData === '0x0000000000000000000000000000000000000000000000000000000000000000') {
    // 查不到数据就返回空
    return null;
  }

  const amountHex = await publicClient.getStorageAt({
    address: contractAddress,
    slot: toHex(amountSlot),
  });

  // 解析读取的数据 userAndStartTimeSlotData 类似: 0x0000000000000000000000000000000000000000000000000de0b6b3a7640000
  // 长度 66, 去除 0x 还有 64 位 
  const user = '0x' + userAndStartTimeSlotData!.slice(26); // 取最后 40 位字符（地址）
  const startTime = new Date(parseInt(userAndStartTimeSlotData!.slice(10, 26), 16) * 1000).toLocaleString(); // 取前 16 位字符（时间戳）
  const amount = BigInt(amountHex!);
  console.log("===========slotData", user, startTime, amount)

  return {
    user,
    startTime: startTime.toString(),
    amount: amount.toString(),
  };
}

export const getSlotInfo = async (index: any) => {
    return getLockInfo(index);
}