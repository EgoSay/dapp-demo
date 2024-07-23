// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EsRNTToken is ERC20Permit, Ownable{

    uint256 public constant MAX_LOCKED_TIME = 30 days;

    // user staked token
    address public stakedToken;

    // user locked reward info
    struct LockedReward {
        address user;
        uint256 amount;
        uint256 lockedAt;
    }
    // LockedReward[] public lockedRewards;
    mapping(uint256 => LockedReward) public lockedRewards;

    constructor(address _stakedToken) ERC20("EsRNTToken", "esRNT") ERC20Permit("EsRNTToken") Ownable(msg.sender) {
        stakedToken = _stakedToken;
    }

     /**
     * @dev Restricted to members of the operator role.
     */
    modifier onlyOperator() {
        // TODO:  set operator permission
        // require(hasRole(OPERATOR_ROLE, msg.sender), "StakePool#onlyOperator: CALLER_NO_OPERATOR_ROLE");
        _;
    }

    /**
     * @dev Mint and lock the reward for the user.
     * @param to The address of the user to mint and lock the reward for.
     * @param amount The amount of reward to mint and lock.
     *
     */
    function mintAndLock(address to, uint256 amount) public onlyOperator {
        IERC20(stakedToken).transfer(address(this), amount);
        _mint(to, amount);
        addLockedReward(to, amount);
        emit MintAndLocked(to, amount, block.timestamp);
    }


    function addLockedReward(address user, uint256 amount) public onlyOperator {
        LockedReward memory reward = LockedReward(user, amount, block.timestamp);
        uint256 rewardId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, reward.user, reward.amount)));
        lockedRewards[rewardId] = reward;
    }


    /**
     * @dev Withdraw and burn the reward for the user.
     * @param lockedId The id of the locked reward to withdraw and burn.
     *
     */
    function withdrawAndBurn(uint256 lockedId) public {
        LockedReward memory reward = lockedRewards[lockedId];
        require(reward.user == msg.sender, "EsRNTToken: caller is not the reward owner");

        uint256 rewardAmount = getLockedReward(reward);
        IERC20(stakedToken).transfer(msg.sender, rewardAmount);

        uint256 burnAmount = reward.amount;
        _burn(msg.sender, burnAmount);

        emit WithdrawAndBurn(msg.sender, rewardAmount, burnAmount);
    }

    function getLockedReward(LockedReward memory reward) public view returns (uint256){
        uint256 timeElapsed = block.timestamp - reward.lockedAt;
        uint256 rewardAmount = reward.amount;
        if (timeElapsed < MAX_LOCKED_TIME) {
            rewardAmount = rewardAmount * timeElapsed / MAX_LOCKED_TIME;
        }
        return rewardAmount;
    }

    event MintAndLocked(address indexed user, uint256 amount, uint256 lockedAt);
    event WithdrawAndBurn(address indexed from, uint256 depositAmount, uint256 burnAmount);
}
