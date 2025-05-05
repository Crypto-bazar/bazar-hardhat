// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

contract DAONFT is ERC721 {
    DAOToken public governanceToken;
    IERC20 public paymentToken;
    uint256 private _tokenIdCounter;
    uint256 public tokenPrice;
    uint256 public paymentTokenPrice;

    struct NFTProposal {
        string tokenURI;
        address proposer;
        uint256 votes;
        bool minted;
        uint256 mintedTokenId; // Добавлено: храним ID minted токена
    }

    struct NFTSales {
        uint256 tokenId;
        address owner;
        address creator;
        uint256 price;
        bool sold;
    }

    // Добавлено: mapping для быстрого поиска creator по tokenId
    mapping(uint256 => address) public tokenIdToCreator;
    
    mapping(uint256 => NFTProposal) public nftProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => NFTSales) public nftSales;

    uint256 public proposalCounter;
    uint256 public baseRequiredVotes = 1000 * 10**18;
    uint256 public difficultyDivider = 1000000000000;
    uint256 public creationTimestamp;

    event NFTProposed(uint256 indexed proposalId, string tokenURI, address proposer);
    event Voted(uint256 indexed proposalId, address indexed voter, string tokenURI, uint256 amount);
    event NFTInSale(uint256 indexed tokenId, address indexed owner, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event NFTMinted(uint256 indexed tokenId, string tokenURI, address owner);

    constructor(
        address _governanceToken,
        address _paymentToken,
        uint256 _tokenPrice,
        uint256 _paymentTokenPrice
    ) ERC721("DAONFT", "DNFT") {
        governanceToken = DAOToken(_governanceToken);
        paymentToken = PaymentToken(_paymentToken);
        tokenPrice = _tokenPrice;
        paymentTokenPrice = _paymentTokenPrice;
        creationTimestamp = block.timestamp;
    }

    function mintNFT() public {
        _mint(msg.sender, _tokenIdCounter++);
    }

    // Улучшенная функция сложности, учитывающая время и количество предложений
    function getRequiredVotes() public view returns (uint256) {
        uint256 timeFactor = (block.timestamp - creationTimestamp) / 1 weeks;
        uint256 proposalFactor = proposalCounter * 10**18;
        return baseRequiredVotes + timeFactor + proposalFactor;
    }

    function buyPopTokens(uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than 0");
        uint256 ethRequired = amount * paymentTokenPrice;
        require(msg.value >= ethRequired, "Insufficient ETH sent");

        uint256 contractBalance = paymentToken.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient tokens in contract");

        bool success = paymentToken.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        if (msg.value > ethRequired) {
            payable(msg.sender).transfer(msg.value - ethRequired);
        }

        emit TokensPurchased(msg.sender, ethRequired, amount);
    }

    function buyGovernanceTokens(uint256 amount) public {
        uint256 cost = amount * tokenPrice;

        require(
            paymentToken.transferFrom(msg.sender, address(this), cost),
            "Payment failed"
        );

        governanceToken.mint(msg.sender, amount);

        emit TokensPurchased(msg.sender, amount, cost);
    }

    function buyNFT(uint256 tokenId) public {
        NFTSales storage sale = nftSales[tokenId];

        require(!sale.sold, "NFT already sold");
        require(sale.price > 0, "NFT not for sale");

        uint256 creatorFee = (sale.price * 1) / 100;
        uint256 sellerAmount = sale.price - creatorFee;

        require(
            paymentToken.transferFrom(msg.sender, address(this), sale.price),
            "Payment failed"
        );

        require(
            paymentToken.transfer(sale.creator, creatorFee),
            "Creator fee failed"
        );
        require(
            paymentToken.transfer(sale.owner, sellerAmount),
            "Payment to seller failed"
        );

        _transfer(sale.owner, msg.sender, tokenId);
        sale.sold = true;

        emit NFTSold(tokenId, msg.sender, sale.price);
    }

    function sellNFT(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        
        // Теперь creator можно получить напрямую из mapping
        address creator = tokenIdToCreator[tokenId];
        require(creator != address(0), "Creator not found");

        nftSales[tokenId] = NFTSales({
            tokenId: tokenId,
            owner: msg.sender,
            creator: creator,
            price: price,
            sold: false
        });

        emit NFTInSale(tokenId, msg.sender, price);
    }

    function proposeNFT(string memory _tokenURI) public {
        proposalCounter++;

        nftProposals[proposalCounter] = NFTProposal({
            tokenURI: _tokenURI,
            proposer: msg.sender,
            votes: 0,
            minted: false,
            mintedTokenId: 0
        });

        emit NFTProposed(proposalCounter, _tokenURI, msg.sender);
    }

    function voteForNFT(uint256 proposalId) public {
        require(
            nftProposals[proposalId].proposer != address(0),
            "Proposal does not exist"
        );
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No governance tokens");

        nftProposals[proposalId].votes += voterBalance;
        hasVoted[proposalId][msg.sender] = true;

        emit Voted(
            proposalId,
            msg.sender,
            nftProposals[proposalId].tokenURI,
            voterBalance
        );

        if (nftProposals[proposalId].votes >= getRequiredVotes()) {
            mintApprovedNFT(proposalId);
        }
    }

    function mintApprovedNFT(uint256 proposalId) internal {
        NFTProposal storage proposal = nftProposals[proposalId];
        require(!proposal.minted, "Already minted");

        uint256 newTokenId = _tokenIdCounter;
        _mint(proposal.proposer, newTokenId);
        
        // Сохраняем информацию о creator
        tokenIdToCreator[newTokenId] = proposal.proposer;
        
        proposal.minted = true;
        proposal.mintedTokenId = newTokenId;
        _tokenIdCounter++;

        emit NFTMinted(newTokenId, proposal.tokenURI, proposal.proposer);
    }

    function getProposeNFT() public view returns (NFTProposal[] memory) {
        NFTProposal[] memory proposals = new NFTProposal[](proposalCounter);
        for (uint256 i = 0; i < proposalCounter; i++) {
            proposals[i] = nftProposals[i + 1];
        }
        return proposals;
    }
}