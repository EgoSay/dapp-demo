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

    
    function addLockedReward(address user, uint256 amount) public onlyOwner() {
        lockedRewards.push(LockedReward(user, amount, block.timestamp));
    }


    /*
     * @dev Withdraw and burn the reward for the user.
     * @param lockedId The id of the locked reward to withdraw and burn.
     *
     */
    function withdrawAndBurn() public {
        // use assembly read user's reward
        uint256 rewardAmount;
        uint256 burnAmount;
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

    function getLockedReward(LockedReward memory reward) public view returns (uint256){
        uint256 timeElapsed = block.timestamp - reward.lastUpdateTime;
        uint256 rewardAmount = reward.amount;
        if (timeElapsed < MAX_LOCKED_TIME) {
            rewardAmount = rewardAmount * timeElapsed / MAX_LOCKED_TIME;
        }
        return rewardAmount;
    }

    event MintAndLocked(address indexed user, uint256 amount, uint256 lockedAt);
    event WithdrawAndBurn(address indexed from, uint256 depositAmount, uint256 burnAmount);
}
