import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("DAO Contracts", function() {
  async function deployDAOFixture() {
    const [owner, voter1, voter2, proposer, buyer] = await hre.ethers.getSigners();
    const initialSupply = 1_000_000;

    const DAOToken = await hre.ethers.getContractFactory("DAOToken");
    const daoToken = await DAOToken.deploy(initialSupply);

    const PaymentToken = await hre.ethers.getContractFactory("PaymentToken");
    const paymentToken = await PaymentToken.deploy(initialSupply);

    const DAONFT = await hre.ethers.getContractFactory("DAONFT");
    const daoNFT = await DAONFT.deploy(daoToken.getAddress(), paymentToken.getAddress(), 100000000, 100000000);

    await daoToken.mint(voter1.address, 500000);
    await daoToken.mint(voter2.address, 600000);
    await daoToken.mint(proposer.address, 100);
    await daoToken.mint(await daoNFT.getAddress(), 1_000_000n * 10n ** 18n);
    await daoToken.changeOwner(daoNFT.getAddress())
    await paymentToken.mint(buyer.address, 1000);

    return {
      daoToken,
      paymentToken,
      daoNFT,
      owner,
      voter1,
      voter2,
      proposer,
      buyer,
    };
  }

  describe("DAOToken", function() {
    it("Should deploy with correct initial supply", async function() {
      const { daoToken, owner } = await loadFixture(deployDAOFixture);
      const expected = await daoToken.balanceOf(owner.address);
      expect(expected).to.be.gt(0);
    });

    it("Should allow minting by owner", async function() {
      const { daoToken, voter1 } = await loadFixture(deployDAOFixture);
      await expect(daoToken.mint(voter1.address, 1000)).to.be.rejectedWith("Only owner can mint")
      const balance = await daoToken.balanceOf(voter1.address);
      expect(balance).to.equal(BigInt(500000) * 10n ** 18n); // 500
    });

    it("Should prevent minting by non-owner", async function() {
      const { daoToken, voter1 } = await loadFixture(deployDAOFixture);
      await expect(daoToken.connect(voter1).mint(voter1.address, 100)).to.be.revertedWith("Only owner can mint");
    });
  });

  describe("DAONFT", function() {
    it("Should deploy with governance and payment tokens", async function() {
      const { daoNFT, daoToken, paymentToken } = await loadFixture(deployDAOFixture);
      expect(await daoNFT.governanceToken()).to.equal(await daoToken.getAddress());
      expect(await daoNFT.paymentToken()).to.equal(await paymentToken.getAddress());
    });

    it("Should propose new NFT", async function() {
      const { daoNFT, proposer } = await loadFixture(deployDAOFixture);
      const uri = "ipfs://test";
      await expect(daoNFT.connect(proposer).proposeNFT(uri))
        .to.emit(daoNFT, "NFTProposed")
        .withArgs(1, uri, proposer.address);
    });

    it("Should allow voting and mint NFT", async function() {
      const { daoNFT, voter1, voter2, proposer } = await loadFixture(deployDAOFixture);
      const uri = "ipfs://dao-nft";
      await daoNFT.connect(proposer).proposeNFT(uri);

      await daoNFT.connect(voter1).voteForNFT(1);

      await expect(daoNFT.connect(voter2).voteForNFT(1))
        .to.emit(daoNFT, "NFTMinted")
        .withArgs(0, uri, proposer.address);

      expect(await daoNFT.ownerOf(0)).to.equal(proposer.address);
    });

    it("Should prevent double voting", async function() {
      const { daoNFT, daoToken, voter1, proposer } = await loadFixture(deployDAOFixture);
      await daoNFT.connect(proposer).proposeNFT("ipfs://123");

      await daoToken.connect(voter1).approve(await daoNFT.getAddress(), 500n * 10n ** 18n);
      await daoNFT.connect(voter1).voteForNFT(1);

      await expect(daoNFT.connect(voter1).voteForNFT(1)).to.be.revertedWith("Already voted");
    });

    it("Should allow selling and buying NFT", async function() {
      const { daoNFT, daoToken, paymentToken, proposer, buyer, voter1, voter2 } = await loadFixture(deployDAOFixture);
      const uri = "ipfs://market-nft";

      await daoNFT.connect(proposer).proposeNFT(uri);
      await daoNFT.connect(voter1).voteForNFT(1);
      await daoNFT.connect(voter2).voteForNFT(1);

      const tokenId = 0;

      await daoToken.connect(proposer).approve(await daoNFT.getAddress(), 100n * 10n ** 18n);
      await daoNFT.connect(proposer).sellNFT(tokenId, 100n * 10n ** 18n);

      await paymentToken.connect(buyer).approve(await daoNFT.getAddress(), 100n * 10n ** 18n);
      await expect(daoNFT.connect(buyer).buyNFT(tokenId))
        .to.emit(daoNFT, "NFTSold")
        .withArgs(tokenId, buyer.address, 100n * 10n ** 18n);

      expect(await daoNFT.ownerOf(tokenId)).to.equal(buyer.address);
    });

    it("Should buy Governance tokens", async function() {
      const { daoNFT, paymentToken, buyer, daoToken } = await loadFixture(deployDAOFixture);
      const amount = 1000n * 10n ** 18n;
      await paymentToken.connect(buyer).approve(await daoNFT.getAddress(), amount);

      await expect(daoNFT.connect(buyer).buyGovernanceTokens(amount))
        .to.emit(daoNFT, "TokensPurchased")
        .withArgs(buyer.address, amount, amount);
      expect(await daoToken.balanceOf(buyer)).to.equal(await daoToken.balanceOf(buyer.address));
    });

    it("Should return all proposals", async function() {
      const { daoNFT, proposer } = await loadFixture(deployDAOFixture);
      await daoNFT.connect(proposer).proposeNFT("ipfs://1");
      await daoNFT.connect(proposer).proposeNFT("ipfs://2");

      const proposals = await daoNFT.getProposeNFT();
      expect(proposals.length).to.equal(2);
      expect(proposals[0].tokenURI).to.equal("ipfs://1");
      expect(proposals[1].tokenURI).to.equal("ipfs://2");
    });

  });
});
