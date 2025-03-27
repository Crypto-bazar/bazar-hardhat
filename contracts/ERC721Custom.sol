// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomERC721 is ERC721, Ownable {
    uint256 private _tokenIdCounter; 
    string private _baseTokenURI;

    mapping(uint256 => string) private _tokenURIs;

    struct TokenInfo {
        uint256 price;
        address seller;
        bool isForSale;
    }

    mapping(uint256 => TokenInfo) public tokenInfo;

    event TokenMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string tokenURI
    );
    event TokenListedForSale(
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller
    );
    event TokenSold(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        _tokenIdCounter = 0; 
    }

    function mintToken(string memory _tokenURI) public returns (uint256) {
        _tokenIdCounter++; 
        uint256 newTokenId = _tokenIdCounter;
        _mint(msg.sender, newTokenId);

        _tokenURIs[newTokenId] = _tokenURI;

        emit TokenMinted(newTokenId, msg.sender, _tokenURI);
        return newTokenId;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Token does not exist");
        return _tokenURIs[_tokenId];
    }

    function _exists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function listTokenForSale(uint256 _tokenId, uint256 _price) public {
        require(
            ownerOf(_tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        require(_price > 0, "Price must be greater than 0");

        tokenInfo[_tokenId] = TokenInfo({
            price: _price,
            seller: msg.sender,
            isForSale: true
        });

        emit TokenListedForSale(_tokenId, _price, msg.sender);
    }

    function buyToken(uint256 _tokenId) public payable {
        TokenInfo memory info = tokenInfo[_tokenId];
        require(info.isForSale, "Token is not for sale");
        require(msg.value >= info.price, "Insufficient funds");

        address seller = info.seller;
        uint256 price = info.price;

        _transfer(seller, msg.sender, _tokenId);
        payable(seller).transfer(price);

        delete tokenInfo[_tokenId];

        emit TokenSold(_tokenId, msg.sender, price);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}