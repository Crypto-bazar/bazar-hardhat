// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Token.sol";

contract NFTMarket {
    address public owner;
    address[] public tokenList;
    SalesNFT[] public salesTokenList;

    struct NFT {
        address addressToken;
        string name;
        string symbol;
        string uri;
        uint256 amount;
    }

    struct SalesNFT {
        NFT nft;
        uint price;
        address seller;
        bool isSold;
    }

    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint price);

    constructor() {
        owner = msg.sender;
    }

    // Функция для создания нового NFT
    function createNFT(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public returns (address) {
        Token nft = new Token(_name, _symbol, _uri);
        tokenList.push(address(nft));
        nft.mintNFT(msg.sender);
        return address(nft);
    }

    // Функция для выставления NFT на продажу
    function sellNFT(address _nftAddress, uint _price) public returns (bool) {
        Token nft = Token(_nftAddress);
        require(nft.balanceOf(msg.sender) > 0, "You do not own this NFT");
        require(_price > 0, "Price must be greater than 0");

        NFT memory nftData = NFT({
            addressToken: _nftAddress,
            name: nft.name(),
            symbol: nft.symbol(),
            uri: nft.getTokenUri(),
            amount: nft.balanceOf(msg.sender)
        });

        salesTokenList.push(SalesNFT({
            nft: nftData,
            price: _price,
            seller: msg.sender,
            isSold: false
        }));

        return true;
    }

    // Функция для покупки NFT
    function buyNFT(uint _index) public payable {
        require(_index < salesTokenList.length, "Invalid index");
        SalesNFT storage sale = salesTokenList[_index];
        require(!sale.isSold, "NFT is already sold");
        require(msg.value >= sale.price, "Insufficient funds");

        // Token nft = Token(sale.nft.addressToken);
        // nft.transferToken(sale.seller, msg.sender); 

        sale.isSold = true;
        payable(sale.seller).transfer(msg.value);

        emit NFTSold(msg.sender, sale.seller, sale.nft.addressToken, sale.price);
    }

    // Функция для получения информации о NFT
    function getNFT(address _addressToken) external view returns (NFT memory) {
        Token nft = Token(_addressToken);
        return
            NFT({
                addressToken: _addressToken,
                name: nft.name(),
                symbol: nft.symbol(),
                uri: nft.getTokenUri(),
                amount: nft.balanceOf(msg.sender)
            });
    }

    // Функция для передачи NFT другому адресу
    function transferNFT(address _tokenAddress, address _to) external {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_to != address(0), "Invalid recipient address");
        Token token = Token(_tokenAddress);
        token.transferToken(msg.sender, _to);
    }

    function getSalesTokenList() external view returns (SalesNFT[] memory) {
        uint availableCount = 0;

        // Подсчитываем количество доступных для продажи NFT
        for (uint i = 0; i < salesTokenList.length; i++) {
            if (!salesTokenList[i].isSold) {
                availableCount++;
            }
        }

        // Создаем массив для хранения доступных NFT
        SalesNFT[] memory availableSales = new SalesNFT[](availableCount);
        uint index = 0;

        // Заполняем массив доступными NFT
        for (uint i = 0; i < salesTokenList.length; i++) {
            if (!salesTokenList[i].isSold) {
                availableSales[index] = salesTokenList[i];
                index++;
            }
        }

        return availableSales;
    }
}