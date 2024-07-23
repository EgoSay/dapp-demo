// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20 {
    constructor() ERC20("MyERC20", "CJW") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}

contract MyIDO {
    function preSale() public {
        // TODO: Implement preSale function
    }

    function claim() public {
        // TODO: Implement claim function
    }

    function withdraw() public {
        // TODO: Implement withdraw function
    }
}