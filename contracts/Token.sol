// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAOToken is ERC20 {
    address public owner;

    constructor(uint256 initialSupply) ERC20("DAO Token", "DAOT") {
        owner = msg.sender;
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only owner can mint");
        _mint(to, amount);
    }

    function changeOwner(address _ownerAddress) public {
        require(msg.sender == owner, "Only owner can change");
        owner = _ownerAddress;
    }
}

contract PaymentToken is ERC20 {
    address public owner;

    constructor(uint256 initialSupply) ERC20("POP", "POP") {
        owner = msg.sender;
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only owner can mint");
        _mint(to, amount);
    }
}
