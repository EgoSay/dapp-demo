// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyERC20 is ERC20 {

    uint256 public totalSupplyLimit;
    uint256 public perMint;
    uint256 public mintedSupply;
    address public  owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(string memory symbol_, uint256 totalSupply_, uint256 _perMint) ERC20(symbol_, symbol_) {
        totalSupplyLimit = totalSupply_;
        perMint = _perMint;
        owner = msg.sender;
    }

    function initialize(string memory symbol_, uint256 totalSupply_, uint256 _perMint) public {
        owner = msg.sender;
        totalSupplyLimit = totalSupply_;
        perMint = _perMint;
    }

    function mint(address to) public onlyOwner {
        require(mintedSupply + perMint <= totalSupplyLimit, "Exceeds total supply");
        _mint(to, perMint);
        mintedSupply += perMint;
    }
}