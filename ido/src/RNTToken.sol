// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RNTToken is ERC20Permit, Ownable{
    constructor() ERC20("RNTToken", "RNT") ERC20Permit("RNTToken") Ownable(msg.sender) {
        _mint(msg.sender, 100_0000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
