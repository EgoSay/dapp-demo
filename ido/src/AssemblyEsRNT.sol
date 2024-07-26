// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EsRNTToken is ERC20Permit, Ownable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant MAX_LOCKED_TIME = 30 days;

    // user staked token
    address public stakedToken;

    // user locked reward info
    LockedReward[] public lockedRewards;
    struct LockedReward {
        address user;
        uint256 amount;
        uint256 lastUpdateTime;
    }
    // mapping(uint256 => LockedReward) public lockedRewards;
    constructor(address _stakedToken) ERC20("EsRNTToken", "esRNT") ERC20Permit("EsRNTToken") Ownable(msg.sender) {
        stakedToken = _stakedToken;
    }

    /**
     * @dev Mint and lock the reward for the user.
     * @param to The address of the user to mint and lock the reward for.
     * @param amount The amount of reward to mint and lock.
     *
     */
    function mintAndLock(address to, uint256 amount) public onlyOwner returns(uint256){
        require(IERC20(stakedToken).transfer(address(this), amount), "stake token transfer failed");

        _mint(to, amount);
        uint256 lockId = lockedRewards.length;
        lockedRewards[lockId] = LockedReward(to, amount, block.timestamp);

        emit MintAndLocked(to, lockId, block.timestamp);
        return lockId;
    }
    

    /*
     * @dev Withdraw and burn the reward for the user.
     * @param lockedId The id of the locked reward to withdraw and burn.
     *
     */
    function withdrawAndBurn(uint256 lockedId) private {
        LockedReward memory reward = lockedRewards[lockedId];
        uint256 rewardAmount = getLockedReward(reward);
        _burn(reward.user, reward.amount);
        IERC20(stakedToken).transfer(reward.user, rewardAmount);
        emit WithdrawAndBurn(reward.user, rewardAmount, reward.amount);
    }


    function getLockedReward(LockedReward memory reward) public view returns (uint256){
        uint256 timeElapsed = block.timestamp - reward.lastUpdateTime;
        uint256 rewardAmount = reward.amount;
        if (timeElapsed < MAX_LOCKED_TIME) {
            rewardAmount = rewardAmount * timeElapsed / MAX_LOCKED_TIME;
        }
        return rewardAmount;
    }
    
    /*
     * @dev Withdraw and burn all the reward for the user.
     *
     */
    function withdrawAllAndBurn() public {
        // use assembly read user's reward
        uint256 rewardAmount;
        uint256 burnAmount;
        // LockedReward[] memory userRewards findLockedRewards(msg.sender);
        for (uint256 i = 0; i < lockedRewards.length; i++) {
            LockedReward memory reward = lockedRewards[i];
            if (reward.user == msg.sender) {
                rewardAmount += getLockedReward(reward);
                burnAmount += reward.amount;
            }
        }
        
        IERC20(stakedToken).transfer(msg.sender, rewardAmount);
        _burn(msg.sender, burnAmount);
        emit WithdrawAndBurn(msg.sender, rewardAmount, burnAmount);
    }


    function findLockedRewards(address user) internal view returns (LockedReward[] memory userRewards) {
        uint256 len = lockedRewards.length;
        uint256 count = 0;
        // Allocate memory for storing userRewards
        LockedReward[] memory tempRewards = new LockedReward[](len);

        // Iterate over lockedRewards array using inline assembly
        assembly {
            // Get the base slot for lockedRewards array elements
            let baseSlot := keccak256(add(lockedRewards.slot, 0), 0x20)
            
            // Loop through the array
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                // Calculate the storage slot of the current LockedReward struct
                // 因为每个 LockedReward 结构体占用 3 个 slot，所以需要乘以 2
                let slot := add(baseSlot, mul(i, 3))

                // 第一个 slot 存储 address 和 amount (20 bytes + 12 bytes)，第二个 slot 存储 lastUpdateTime (uint32 4 bytes) 
                let data1 := sload(slot)
                // Load the remaining part of the struct (rest of amount and lockedAt)
                let data2 := sload(add(slot, 1))

                // 因为存储是低位对齐，所以 右移 96/8 = 12 bytes 就是 address 的值
                let rewardUser := shr(96, data1)
                
                // 如果是当前用户地址
                if eq(rewardUser, user) {
                    // Extract amount (remaining 12 bytes of data1 and first 4 bytes of data2)
                    let rewardAmount := and(data1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    rewardAmount := or(rewardAmount, shl(96, and(data2, 0xFFFFFFFF)))

                    // Extract lockedAt (remaining 28 bytes of data2)
                    let rewardLockedAt := shr(32, data2)

                    // Store the struct in tempRewards array
                    let offset := mul(count, 0x60)
                    mstore(add(tempRewards, offset), rewardUser)
                    mstore(add(add(tempRewards, offset), 0x20), rewardAmount)
                    mstore(add(add(tempRewards, offset), 0x40), rewardLockedAt)
                    
                    // Increment the count
                    count := add(count, 1)
                }
            }
        }

        // Resize userRewards array to the correct length
        return tempRewards;
    }


    event MintAndLocked(address indexed user, uint256 amount, uint256 lockedAt);
    event WithdrawAndBurn(address indexed from, uint256 depositAmount, uint256 burnAmount);
}
