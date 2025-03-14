// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC721, Ownable {
    string private _baseTokenURI;  // Базовый URI для метаданных
    uint256 private _tokenIdCounter = 1;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        _tokenIdCounter++;
    }

    // Функция для минтинга нового NFT
    function mintNFT(address recipient) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _safeMint(recipient, tokenId);
        _tokenIdCounter++; // Увеличиваем ID для следующего токена
    }

    function transferToken(address _from, address _to) public {
        transferFrom(_from, _to, 1);
    }

    // Установка базового URI (если нужно менять)
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getBalance() public view returns(uint256) {
        return balanceOf(msg.sender);
    }

    // Переопределение функции baseURI
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function getTokenUri() public view returns(string memory) {
        return _baseTokenURI;
    } 
}