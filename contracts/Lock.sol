// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Test {

    struct Product {
        string name;
        uint price;
        uint quantity;
    }

    mapping (address => Product[]) public userProducts;

    event ProductUpdate(Product product);

    function createProduct(string memory _name, uint _price, uint _quantity) public {
        Product memory product = Product(_name, _price, _quantity);
        userProducts[msg.sender].push(product);
        emit ProductUpdate(product);
    }

    function getUserProducts() public view returns (Product[] memory) {
        return userProducts[msg.sender];
    }
}
