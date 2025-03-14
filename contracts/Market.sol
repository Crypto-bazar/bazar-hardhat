// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";

contract NFTMarket {
    address owner;

    address[] public tokenList;

    constructor() {
        owner = msg.sender;
    }

    function createNFT(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public {
        Token nft = new Token(_name, _symbol, _uri);
        tokenList.push(address(nft));
    }

    function getNFT(uint256 _id)
        external
        view
        returns (
            string memory name,
            string memory symbol,
            string memory uri
        )
    {
        Token nft = Token(tokenList[_id]);
        return (nft.name(), nft.symbol(), nft.getTokenUri());
    }
}