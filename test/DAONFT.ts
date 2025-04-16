import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("DAO Contracts", function () {
  async function deployDAOFixture() {
    const [owner, voter1, voter2, proposer] = await hre.ethers.getSigners();
    const initialSupply = 1000000;
    const requiredVotes = 1000 * 10**18;

    // Деплоим DAOToken
    const DAOToken = await hre.ethers.getContractFactory("DAOToken");
    const daoToken = await DAOToken.deploy(initialSupply);

    // Деплоим DAONFT с передачей адреса токена
    const DAONFT = await hre.ethers.getContractFactory("DAONFT");
    const daoNFT = await DAONFT.deploy(daoToken.target);

    // Распределяем токены для тестирования голосования
    await daoToken.mint(voter1.address, 500); // 500 токенов
    await daoToken.mint(voter2.address, 600); // 600 токенов
    await daoToken.mint(proposer.address, 100); // 100 токенов

    return { 
      daoToken, 
      daoNFT, 
      owner, 
      voter1, 
      voter2, 
      proposer,
      initialSupply,
      requiredVotes
    };
  }

  describe("DAOToken", function () {
    it("Should deploy with correct initial supply", async function () {
      const { daoToken, initialSupply, owner } = await loadFixture(deployDAOFixture);
      const decimals = await daoToken.decimals();
      const expectedBalance = BigInt(initialSupply) * (10n ** BigInt(decimals));
      
      expect(await daoToken.balanceOf(owner.address)).to.equal(expectedBalance);
    });

    it("Should have correct name and symbol", async function () {
      const { daoToken } = await loadFixture(deployDAOFixture);
      
      expect(await daoToken.name()).to.equal("DAO Token");
      expect(await daoToken.symbol()).to.equal("DAOT");
    });

    it("Should allow owner to mint new tokens", async function () {
      const { daoToken, voter1 } = await loadFixture(deployDAOFixture);
      const mintAmount = 1000;
      const decimals = await daoToken.decimals();
      
      await expect(daoToken.mint(voter1.address, mintAmount))
        .to.emit(daoToken, "Transfer")
        .withArgs(hre.ethers.ZeroAddress, voter1.address, BigInt(mintAmount) * (10n ** BigInt(decimals)));
    });

    it("Should prevent non-owners from minting", async function () {
      const { daoToken, voter1 } = await loadFixture(deployDAOFixture);
      
      await expect(daoToken.connect(voter1).mint(voter1.address, 100))
        .to.be.revertedWith("Only owner can mint");
    });
  });

  describe("DAONFT", function () {
    it("Should deploy with correct governance token", async function () {
      const { daoNFT, daoToken } = await loadFixture(deployDAOFixture);
      
      expect(await daoNFT.governanceToken()).to.equal(daoToken.target);
    });

    it("Should allow proposing new NFTs", async function () {
      const { daoNFT, proposer } = await loadFixture(deployDAOFixture);
      const tokenURI = "ipfs://test-uri";
      
      await expect(daoNFT.connect(proposer).proposeNFT(tokenURI))
        .to.emit(daoNFT, "NFTProposed")
        .withArgs(1, tokenURI, proposer.address);
    });

    describe("Voting", function () {
      it("Should allow token holders to vote", async function () {
        const { daoNFT, daoToken, voter1, proposer } = await loadFixture(deployDAOFixture);
        const tokenURI = "ipfs://test-uri";
        
        await daoNFT.connect(proposer).proposeNFT(tokenURI);
        
        // Даем разрешение DAONFT тратить токены voter1
        await daoToken.connect(voter1).approve(daoNFT.target, 500 * 10**18);
        
        await expect(daoNFT.connect(voter1).voteForNFT(1))
          .to.emit(daoNFT, "Voted")
          .withArgs(1, voter1.address, tokenURI);
        
        const proposal = await daoNFT.nftProposals(1);
        expect(proposal.votes).to.equal(500 * 10**18);
      });

      it("Should prevent double voting", async function () {
        const { daoNFT, daoToken, voter1, proposer } = await loadFixture(deployDAOFixture);
        await daoNFT.connect(proposer).proposeNFT("ipfs://test-uri");
        await daoToken.connect(voter1).approve(daoNFT.target, 500 * 10**18);
        
        await daoNFT.connect(voter1).voteForNFT(1);
        
        await expect(daoNFT.connect(voter1).voteForNFT(1))
          .to.be.revertedWith("Already voted");
      });

      it("Should mint NFT when required votes reached", async function () {
        const { daoNFT, daoToken, voter1, voter2, proposer } = await loadFixture(deployDAOFixture);
        const tokenURI = "ipfs://test-uri";
        
        await daoNFT.connect(proposer).proposeNFT(tokenURI);
        
        // Голосуем двумя аккаунтами
        await daoToken.connect(voter1).approve(daoNFT.target, 500 * 10**18);
        await daoToken.connect(voter2).approve(daoNFT.target, 600 * 10**18);
        
        await daoNFT.connect(voter1).voteForNFT(1);
        await daoNFT.connect(voter2).voteForNFT(1);
        
        // Проверяем что NFT был заминчен
        await expect(daoNFT.connect(proposer).voteForNFT(1))
          .to.emit(daoNFT, "NFTMinted")
          .withArgs(1, tokenURI, proposer.address);
        
        expect(await daoNFT.ownerOf(1)).to.equal(proposer.address);
      });
    });

    describe("Proposals", function () {
      it("Should return all proposals", async function () {
        const { daoNFT, proposer } = await loadFixture(deployDAOFixture);
        const tokenURI1 = "ipfs://test-uri-1";
        const tokenURI2 = "ipfs://test-uri-2";
        
        await daoNFT.connect(proposer).proposeNFT(tokenURI1);
        await daoNFT.connect(proposer).proposeNFT(tokenURI2);
        
        const proposals = await daoNFT.getProposeNFT();
        expect(proposals.length).to.equal(2);
        expect(proposals[0].tokenURI).to.equal(tokenURI1);
        expect(proposals[1].tokenURI).to.equal(tokenURI2);
      });
    });
  });
});