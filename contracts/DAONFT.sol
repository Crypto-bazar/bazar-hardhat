// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

contract DAONFT is ERC721 {
    IERC20 public governanceToken;
    IERC20 public paymentToken;
    uint256 private _tokenIdCounter;
    uint256 public tokenPrice;

    struct NFTProposal {
        string tokenURI;
        address proposer;
        uint256 votes;
        bool minted;
    }

    struct NFTSales {
        uint tokenId;
        address owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => NFTProposal) public nftProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => NFTSales) public nftSales;

    uint256 public proposalCounter;
    uint256 public requiredVotes = 1000 * 10 ** 18;

    event NFTProposed(
        uint256 indexed proposalId,
        string tokenURI,
        address proposer
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        string tokenURI,
        uint amount
    );

    event NFTInSale(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 price
    );

    event NFTSold(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);

    event NFTMinted(uint256 indexed tokenId, string tokenURI, address owner);

    constructor(
        address _governanceToken,
        address _paymentToken,
        uint256 _tokenPrice
    ) ERC721("DAONFT", "DNFT") {
        governanceToken = IERC20(_governanceToken);
        paymentToken = IERC20(_paymentToken);
        _tokenIdCounter = 0;
        proposalCounter = 0;
        tokenPrice = _tokenPrice;
    }
    //TODO доделать покупку DAO токенов. Покупка за POP токены.

    function mintNFT() public {
        _mint(msg.sender, _tokenIdCounter++);
    }

    function getQuorum() public view returns (uint256) {
        return governanceToken.totalSupply() / 100;
    }

    function buyGovernanceTokens(uint256 amount) public {
    uint256 cost = amount * tokenPrice;
    require(
        paymentToken.transferFrom(msg.sender, address(this), cost),
        "Payment failed"
    );

    // Теперь минтим governance токены
    DAOToken(address(governanceToken)).mint(msg.sender, amount);

    emit TokensPurchased(msg.sender, amount, cost);
}

    function buyNFT(uint256 tokenId) public {
        NFTSales storage sale = nftSales[tokenId];

        require(!sale.sold, "NFT already sold");
        require(sale.price > 0, "NFT not for sale");
        require(
            paymentToken.transferFrom(msg.sender, sale.owner, sale.price),
            "Payment failed"
        );

        _transfer(sale.owner, msg.sender, tokenId);
        sale.sold = true;

        emit NFTSold(tokenId, msg.sender, sale.price);
    }

    function sellNFT(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        nftSales[tokenId] = NFTSales({
            tokenId: tokenId,
            owner: msg.sender,
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
            minted: false
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

        if (nftProposals[proposalId].votes >= requiredVotes) {
            mintApprovedNFT(proposalId);
        }
    }

    function mintApprovedNFT(uint256 proposalId) internal {
        NFTProposal storage proposal = nftProposals[proposalId];
        require(!proposal.minted, "Already minted");

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        _mint(proposal.proposer, newTokenId);
        proposal.minted = true;

        emit NFTMinted(newTokenId, proposal.tokenURI, proposal.proposer);
    }

    function getProposeNFT() public view returns (NFTProposal[] memory) {
        NFTProposal[] memory proposals = new NFTProposal[](proposalCounter);
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (nftProposals[i + 1].proposer != address(0)) {
                proposals[i] = nftProposals[i + 1];
            }
        }
        return proposals;
    }
}
