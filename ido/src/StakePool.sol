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


    function stake(uint256 amount) public {
        require(amount > 0, "amount must be greater than 0");
        
        _updateReward(msg.sender);
        stakedInfos[msg.sender].stakedAmount += amount;
        // console.log("stakedAmount", stakedInfos[msg.sender].stakedAmount);    
        // console.log("unClaimedReward", stakedInfos[msg.sender].unClaimedReward);
        // console.log("lastStakedAt", stakedInfos[msg.sender].lastStakedAt);

        // TODO: permit
        //  transfer tokens to contract
        IERC20(RNTToken).transferFrom(msg.sender, address(this), amount);
        emit Stake(msg.sender, amount);
    }

    // stake with signture
    function stakeWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        IERC20Permit(RNTToken).permit(msg.sender, address(this), amount, deadline, v, r,s);
        stake(amount);
    }

     function _updateReward(address user) private{
        StakedInfo storage stakeDetails = stakedInfos[user];
        if (stakeDetails.lastStakedAt == 0) {
            // if there is no staked amount, return
            stakedInfos[user].lastStakedAt = block.timestamp;
            return ;
        }
        // calculate reward based on staked amount and time
        stakeDetails.unClaimedReward += _calUnclaimedReward(stakeDetails);
        stakeDetails.lastStakedAt = block.timestamp;
        // stakedInfos[user] = stakeDetails;
    }

    function _calUnclaimedReward(StakedInfo memory stakeDetails) private view returns (uint256) {
        // calculate reward based on staked amount and time
        uint256 timeElapsed = block.timestamp - stakeDetails.lastStakedAt;
        // 1 * timeElapsed(s) / 1 days
        uint256 canGetReward = stakeDetails.stakedAmount * (rewardRate * timeElapsed / rewardDuration);
        return canGetReward;
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "amount must be greater than 0");
        StakedInfo memory stakeDetails = stakedInfos[msg.sender];
        require(stakeDetails.stakedAmount >= amount, "insufficient balance");

        _updateReward(msg.sender);
        // calculate reward and decrease staked amount
        stakedInfos[msg.sender].stakedAmount -= amount;
        // transfer tokens to user
        IERC20(RNTToken).transfer(msg.sender, amount);
        emit Unstake(msg.sender, amount);
    }

     function claimReward() external {
        _updateReward(msg.sender);

        uint256 unClaimedReward = stakedInfos[msg.sender].unClaimedReward;
        require(unClaimedReward > 0, "no reward to claim");
        stakedInfos[msg.sender].unClaimedReward = 0;

        // transfer reward to user
        // TODO: permit and use the call
        (bool result,) = esRNTToken.call(
                        abi.encodeWithSignature("mintAndLock(address,uint256)",
                        msg.sender, unClaimedReward
                    ));
        require(result, "mintAndLock failed");
        emit Claim(msg.sender, unClaimedReward);
    }

    function getStakeDetails(address user) public view returns (uint256, uint256) {
        StakedInfo memory stakeDetails = stakedInfos[user];
        uint256 unclaimReward = _calUnclaimedReward(stakeDetails) + stakeDetails.unClaimedReward;
        return (stakeDetails.stakedAmount, unclaimReward);
    }

    struct PermitRequest {
        uint256 nonce;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event Stake(address indexed from, uint256 amount);
    event Unstake(address indexed from, uint256 amount);
    event Claim(address indexed from, uint256 amount);
} 
