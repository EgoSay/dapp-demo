// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MyERC20.sol";
import {console} from "forge-std/Test.sol";

contract TokenFactoryV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    // mapping to store the creator of each token
    // key: token address, value: creator address
    mapping(address => address) public tokenCreator;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public returns (address) {
        MyERC20 newToken = new MyERC20(symbol, totalSupply, perMint);
        tokenCreator[address(newToken)] = msg.sender;
        console.log("Token created with address: ", address(newToken));
        console.log("Token creator: ", msg.sender);
        return address(newToken);
    }

    function mintInscription(address tokenAddr) public {
        require(tokenCreator[tokenAddr] == msg.sender, "Not the token creator");
        MyERC20(tokenAddr).mint(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }
}


