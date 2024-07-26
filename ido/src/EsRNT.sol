// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract EsRNTToken is ERC20Permit, Ownable {
    uint256 public constant MAX_LOCKED_TIME = 30 days;

    // user staked token
    address public stakedToken;
    
    struct LockedReward {
        address user;
        uint256 amount;
        uint256 lastUpdateTime;
    }
    // array => locked reward  info
    LockedReward[] public  lockedRewards;

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
        IERC20(stakedToken).transfer(address(this), amount);
        _mint(to, amount);
        uint256 lockId = _addLockedReward(to, amount);
        emit MintAndLocked(to, lockId, block.timestamp);
        return lockId;
    }
    
    function _addLockedReward(address user, uint256 amount) private onlyOwner() returns(uint256) {
        lockedRewards.push(LockedReward({
            user: user,
            amount: amount,
            lastUpdateTime: block.timestamp
        }));
        return lockedRewards.length - 1;
    }


    /*
     * @dev Withdraw and burn the reward for the user.
     * @param lockedId The id of the locked reward to withdraw and burn.
     *
     */
    function withdrawAndBurn(uint256 id) public {
        LockedReward memory reward = lockedRewards[id];
        require(reward.user == msg.sender, "EsRNTToken: not the owner");
        uint256 rewardAmount = getLockedReward(lockedRewards[id]);
        uint256 burnAmount = reward.amount - rewardAmount;
        delete lockedRewards[id];

        IERC20(stakedToken).transfer(msg.sender, rewardAmount);
        IERC20(stakedToken).transfer(address(0), burnAmount);
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

    event MintAndLocked(address indexed user, uint256 lockId, uint256 lockedAt);
    event WithdrawAndBurn(address indexed from, uint256 depositAmount, uint256 burnAmount);
}
