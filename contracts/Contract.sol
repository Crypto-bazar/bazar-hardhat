// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAONFT is ERC721 {
    IERC20 public governanceToken;
    uint256 private _tokenIdCounter;

    struct NFTProposal {
        string tokenURI;
        address proposer;
        uint256 votes;
        bool minted;
    }

    mapping(uint256 => NFTProposal) public nftProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public proposalCounter;
    uint256 public requiredVotes = 1000 * 10**18; // 1000 токенов для успешного голосования

    event NFTProposed(uint256 indexed proposalId, string tokenURI, address proposer);
    event Voted(uint256 indexed proposalId, address indexed voter, uint256 votes);
    event NFTMinted(uint256 indexed tokenId, string tokenURI, address owner);

    constructor(address _governanceToken) ERC721("DAONFT", "DNFT") {
        governanceToken = IERC20(_governanceToken);
        _tokenIdCounter = 0;
        proposalCounter = 0;
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
        require(nftProposals[proposalId].proposer != address(0), "Proposal does not exist");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No governance tokens");

        nftProposals[proposalId].votes += voterBalance;
        hasVoted[proposalId][msg.sender] = true;

        emit Voted(proposalId, msg.sender, voterBalance);

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
}
