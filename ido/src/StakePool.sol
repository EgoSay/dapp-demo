// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EsRNTToken} from "../src/EsRNT.sol";


contract StakePool {

    // user staked token
    address public RNTToken;
    // user get reward token
    address public esRNTToken;
    constructor(address _RNTToken, address _esRNTToken) {
        RNTToken = _RNTToken;
        esRNTToken = _esRNTToken;
    }

    // stake and can get reward rate, set 24 hours get 1 token reward
    uint256 public immutable rewardRate = 1;
    uint256 public immutable rewardDuration = 1 days;

    struct StakedInfo {
        uint256 stakedAmount; // amount of tokens staked by the user
        uint256 unClaimedReward; // reward earned by the user
        uint256 lastStakedAt;  // last staked time
    }
    // mapping to track address and their staked info
    mapping(address => StakedInfo) public stakedInfos;

    struct LockedReward {
        uint256 amount;
        uint256 lockedAt;
    }
    // mapping to track address and their locked reward
    mapping(address => LockedReward) public lockedRewards;


    function stake(uint256 amount) external {
        require(amount > 0, "amount must be greater than 0");
        StakedInfo memory stakeDetails = stakedInfos[msg.sender];
        if (stakeDetails.stakedAmount > 0) {
            // calculate reward and add to unClaimedReward
            uint256 reward = _calculateReward(stakeDetails);
            stakedInfos[msg.sender].unClaimedReward += reward;
        }
        stakedInfos[msg.sender].stakedAmount += amount;
        stakedInfos[msg.sender].lastStakedAt = block.timestamp;
        // TODO: permit
        //  transfer tokens to contract
        IERC20(RNTToken).transferFrom(msg.sender, address(this), amount);
    }

    function _calculateReward(StakedInfo memory stakeDetails) internal view returns (uint256) {
        // calculate reward based on staked amount and time
        uint256 timeElapsed = block.timestamp - stakeDetails.lastStakedAt;
        uint256 canGetRewardRate = rewardRate * timeElapsed / rewardDuration;
        stakeDetails.unClaimedReward += stakeDetails.stakedAmount * canGetRewardRate;
        return stakeDetails.stakedAmount * canGetRewardRate;
    }
     function _updateReward(address user) private{
        StakedInfo storage stakeDetails = stakedInfos[user];
        if (stakeDetails.lastStakedAt == 0) {
            // if there is no staked amount, return
            stakedInfos[user].lastStakedAt = block.timestamp;
            return ;
        }
        // calculate reward based on staked amount and time
        uint256 timeElapsed = block.timestamp - stakeDetails.lastStakedAt;
        // 1 * timeElapsed(s) / 1 days
        uint256 canGetRewardRate = rewardRate * timeElapsed / rewardDuration;  
        stakeDetails.unClaimedReward += stakeDetails.stakedAmount * canGetRewardRate;
        stakeDetails.lastStakedAt = block.timestamp;
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "amount must be greater than 0");
        StakedInfo memory stakeDetails = stakedInfos[msg.sender];
        require(stakeDetails.stakedAmount >= amount, "insufficient balance");
        // calculate reward and decrease staked amount
        stakedInfos[msg.sender].unClaimedReward += _calculateReward(stakeDetails);
        stakedInfos[msg.sender].stakedAmount -= amount;
        stakedInfos[msg.sender].lastStakedAt = block.timestamp;
        // transfer tokens to user
        IERC20(RNTToken).transfer(msg.sender, amount);
    }

     function claimReward() external {
        StakedInfo memory stakeDetails = stakedInfos[msg.sender];
        require(stakeDetails.unClaimedReward > 0, "no reward to claim");
        // calculate reward and add to unClaimedReward
        uint256 reward = stakeDetails.unClaimedReward + _calculateReward(stakeDetails);
        stakedInfos[msg.sender].unClaimedReward = 0;
        stakedInfos[msg.sender].lastStakedAt = block.timestamp;

        // transfer reward to user
        // TODO: permit and use the call
        (bool result,) = esRNTToken.call(
                        abi.encodeWithSignature("mintAndLock(address,uint256)",
                        msg.sender, reward
                    ));
        require(result, "mintAndLock failed");
    
    }
} 
