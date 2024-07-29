// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MyERC20.sol";
import {console} from "forge-std/Test.sol";

contract TokenFactoryV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using Clones for address;

    mapping(address => address) public tokenCreator;
    mapping(address => uint256) public tokenPrice;
    address public implementationContract;

    // constructor() {
    //     _disableInitializers();
    // }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function setImplementation(address _implementation) external onlyOwner {
        implementationContract = _implementation;
        emit MyTokenImplSet(_implementation);
    }

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price) public returns (address) {
        require(implementationContract != address(0), "Implementation not set");
        address clone = implementationContract.clone();
        MyERC20(clone).initialize(symbol, totalSupply, perMint);
        tokenCreator[clone] = msg.sender;
        tokenPrice[clone] = price;
        emit MyTokenCreatorUpdated(clone, msg.sender);
        return clone;
    }

    function mintInscription(address tokenAddr) public payable {
        require(tokenCreator[tokenAddr] == msg.sender, "Not the token creator");
        // need fees to mint
        require(msg.value >= tokenPrice[tokenAddr], "Insufficient payment");
        MyERC20(tokenAddr).mint(msg.sender);
        emit MyTokenMinted(tokenAddr, msg.sender);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    event MyTokenImplSet(address indexed impl);
    event MyTokenCreatorUpdated(address indexed tokenAddr, address indexed creator);
    event MyTokenMinted(address indexed tokenAddr, address indexed to);
}
