// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract MultisigWallet {

    // the sig owners, user mapping to optimize traversal gas consumption 
    // address[] public owners;
    mapping(address => bool) public ownerRoles;
    // how many sig are required to confirm a transaction
    uint public required;
    // the number of transactions
    uint public transactionCount;
    
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }
    
    // mapping from transaction id to transaction
    mapping(uint => Transaction) public transactions;
    // mapping from transaction id to mapping from owner to confirmation status
    mapping(uint => mapping(address => bool)) public confirmations;

    
    modifier onlyOwner() {
        require(ownerRoles[msg.sender], "Not an owner");
        _;
    }
    
    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].to != address(0), "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }
    
    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");
        
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            ownerRoles[owner] = true;
        }
        required = _required;
    }
    
    // the sig contract owner can submit transactions
    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner returns (uint) {  
        uint transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        });
        transactionCount += 1;
        emit Submission(transactionId);
        return transactionId;
    }
    
    // 
    function confirmTransaction(uint transactionId) public onlyOwner transactionExists(transactionId) notExecuted(transactionId) {
        // check if the transaction has already been confirmed by the sender
        require(!confirmations[transactionId][msg.sender], "Transaction already confirmed");
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations += 1;
        emit Confirmation(msg.sender, transactionId);
    }
    
    function executeTransaction(uint transactionId) public transactionExists(transactionId) notExecuted(transactionId) {
        // check if the transaction has enough confirmations
        require(transactions[transactionId].confirmations >= required, "Not enough confirmations");
        Transaction storage _tx = transactions[transactionId];
        _tx.executed = true;
        (bool success, ) = _tx.to.call{value: _tx.value}(_tx.data);
        require(success, "Transaction execution failed");
        emit Execution(transactionId);
    }

    function addOwner(address _owner) public onlyOwner {
        require(_owner != address(0), "Invalid owner");
        require(!ownerRoles[_owner], "Owner already exists");
        ownerRoles[_owner] = true;
        emit OwnerAdded(_owner);
    }

    function removeOwner(address _owner) public onlyOwner {
        require(_owner != address(0), "Invalid owner");
        require(ownerRoles[_owner], "Owner does not exist");
        delete ownerRoles[_owner];
        emit OwnerRemoved(_owner);
    }
    
    receive() external payable {}
        
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
}



