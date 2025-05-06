// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

contract DAONFT is ERC721 {
    DAOToken public governanceToken;
    PaymentToken public paymentToken;
    uint256 private _tokenIdCounter = 1;
    uint256 public tokenPrice;
    uint256 public paymentTokenPrice;

    struct NFT {
        uint256 id;
        string name;
        string description;
        string imagePath;
        uint256 price;
        address owner;
        address creator;
        bool forSale;
        bool isProposal;
        uint256 votes;
        uint256 proposalId;
        bool minted;
        uint256 tokenId;
    }

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    NFT[] public nfts;
    uint256 public proposalCounter;
    uint256 public baseRequiredVotes = 1000 * 10**18;
    uint256 public creationTimestamp;

    event NFTProposed(uint256 indexed proposalId, address proposer);
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 amount
    );
    event NFTListed(
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
    event NFTMinted(uint256 indexed tokenId, address owner);
    event NFTUpdated(uint256 indexed tokenId);

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

    function getRequiredVotes() public view returns (uint256) {
        uint256 timeFactor = (block.timestamp - creationTimestamp) / 1 weeks;
        uint256 proposalFactor = proposalCounter * 10**18;
        return baseRequiredVotes + timeFactor + proposalFactor;
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

    function buyNFT(uint256 tokenId) public {
        NFT storage nft = nfts[tokenId];
        require(nft.forSale, "NFT not for sale");
        require(!nft.isProposal, "Cannot buy proposal");

        uint256 creatorFee = nft.price / 100; // 1% fee
        uint256 sellerAmount = nft.price - creatorFee;

        require(
            paymentToken.transferFrom(msg.sender, address(this), nft.price),
            "Payment failed"
        );
        require(
            paymentToken.transfer(nft.creator, creatorFee),
            "Creator fee failed"
        );
        require(
            paymentToken.transfer(nft.owner, sellerAmount),
            "Payment to seller failed"
        );

        _transfer(nft.owner, msg.sender, nft.tokenId);
        nft.owner = msg.sender;
        nft.forSale = false;

        emit NFTSold(tokenId, msg.sender, nft.price);
    }

    function listNFT(uint256 tokenId, uint256 price) public {
        NFT storage nft = nfts[tokenId];
        require(nft.owner == msg.sender, "Not the owner");
        nft.price = price;
        nft.forSale = true;
        emit NFTListed(tokenId, msg.sender, price);
    }

    function proposeNFT(
        string memory _name,
        string memory _description,
        string memory _imagePath
    ) public {
        uint256 proposalId = nfts.length; // индекс будущей записи

        nfts.push(
            NFT({
                id: proposalId,
                name: _name,
                description: _description,
                imagePath: _imagePath,
                price: 0,
                owner: msg.sender,
                creator: msg.sender,
                forSale: false,
                isProposal: true,
                votes: 0,
                proposalId: proposalId,
                minted: false,
                tokenId: 0
            })
        );

        proposalCounter++;
        emit NFTProposed(proposalId, msg.sender);
    }

    function voteForNFT(uint256 proposalId) public {
        NFT storage nft = nfts[proposalId];
        require(nft.isProposal, "Not a proposal");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No governance tokens");

        nft.votes += voterBalance;
        hasVoted[proposalId][msg.sender] = true;

        emit Voted(proposalId, msg.sender, voterBalance);

        if (nft.votes >= getRequiredVotes() && !nft.minted) {
            _mintNFT(proposalId);
        }
    }

    function _mintNFT(uint256 proposalId) internal {
        NFT storage proposal = nfts[proposalId];
        uint256 newTokenId = _tokenIdCounter++;

        _mint(proposal.creator, newTokenId);

        proposal.minted = true;
        proposal.tokenId = newTokenId;
        proposal.isProposal = false;
        emit NFTMinted(newTokenId, proposal.creator);
    }

    function updateNFT(
        uint256 tokenId,
        string memory _name,
        string memory _description,
        string memory _imagePath
    ) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        NFT storage nft = nfts[tokenId];
        nft.name = _name;
        nft.description = _description;
        nft.imagePath = _imagePath;
        emit NFTUpdated(tokenId);
    }

    function getNFT(uint256 tokenId) public view returns (NFT memory) {
        return nfts[tokenId];
    }

    function getAllNFTs() public view returns (NFT[] memory) {
        NFT[] memory allNFTs = new NFT[](nfts.length);
        for (uint256 i = 0; i < nfts.length; i++) {
            allNFTs[i] = nfts[i];
        }
        return allNFTs;
    }

    function getMintedProposals() public view returns (NFT[] memory) {
        uint256 count = 0;

        // First count how many NFTs were minted from proposals
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (nfts[i].isProposal == false && nfts[i].proposalId != 0) {
                count++;
            }
        }

        // Then populate the array
        NFT[] memory mintedProposals = new NFT[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (nfts[i].isProposal == false && nfts[i].proposalId != 0) {
                mintedProposals[index++] = nfts[i];
            }
        }

        return mintedProposals;
    }
}
