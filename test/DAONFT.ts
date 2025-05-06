import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("DAONFT", function () {
  async function deployDAOFixture() {
    const [owner, proposer, voter1, voter2, buyer] = await ethers.getSigners();

    const DAOToken = await ethers.getContractFactory("DAOToken");
    const daoToken = await DAOToken.deploy("DAO", "DAO");
    await daoToken.waitForDeployment();

    const PaymentToken = await ethers.getContractFactory("PaymentToken");
    const paymentToken = await PaymentToken.deploy("USD", "USD");
    await paymentToken.waitForDeployment();

    const DAONFT = await ethers.getContractFactory("DAONFT");
    const daoNFT = await DAONFT.deploy(
      await daoToken.getAddress(),
      await paymentToken.getAddress()
    );
    await daoNFT.waitForDeployment();

    // distribute governance tokens
    await daoToken.transfer(proposer.address, 100);
    await daoToken.transfer(voter1.address, 100);
    await daoToken.transfer(voter2.address, 100);

    // distribute payment tokens
    await paymentToken.transfer(buyer.address, 1000);

    return { daoNFT, daoToken, paymentToken, proposer, voter1, voter2, buyer };
  }

  it("Should deploy with governance and payment tokens", async function () {
    const { daoNFT, daoToken, paymentToken } = await loadFixture(deployDAOFixture);
    expect(await daoNFT.governanceToken()).to.equal(await daoToken.getAddress());
    expect(await daoNFT.paymentToken()).to.equal(await paymentToken.getAddress());
  });

  it("Should propose new NFT", async function () {
    const { daoNFT, proposer } = await loadFixture(deployDAOFixture);
    const uri = "ipfs://test";
    const name = "Test NFT";
    const description = "Test Description";
    const imagePath = "ipfs://image";

    await expect(daoNFT.connect(proposer).proposeNFT(uri, name, description, imagePath))
      .to.emit(daoNFT, "NFTProposed")
      .withArgs(1, uri, proposer.address);
  });

  it("Should allow voting and mint NFT", async function () {
    const { daoNFT, daoToken, voter1, voter2, proposer } = await loadFixture(deployDAOFixture);
    const uri = "ipfs://dao-nft";
    const name = "DAO NFT";
    const description = "Governance NFT";
    const imagePath = "ipfs://image-dao";

    await daoNFT.connect(proposer).proposeNFT(uri, name, description, imagePath);

    const requiredVotes = await daoNFT.getRequiredVotes();
    const balance1 = await daoToken.balanceOf(voter1.address);
    const balance2 = await daoToken.balanceOf(voter2.address);
    expect(balance1 + balance2).to.be.gte(requiredVotes);

    await daoNFT.connect(voter1).voteForNFT(1);
    const tx = await daoNFT.connect(voter2).voteForNFT(1);

    await expect(tx)
      .to.emit(daoNFT, "NFTMinted")
      .withArgs(0, uri, proposer.address);
  });

  it("Should reject double voting", async function () {
    const { daoNFT, voter1, proposer } = await loadFixture(deployDAOFixture);
    await daoNFT.connect(proposer).proposeNFT("ipfs://dup-vote", "n", "d", "i");

    await daoNFT.connect(voter1).voteForNFT(1);
    await expect(daoNFT.connect(voter1).voteForNFT(1)).to.be.revertedWith("Already voted");
  });

  it("Should sell and buy NFT", async function () {
    const { daoNFT, paymentToken, proposer, buyer, voter1, voter2 } = await loadFixture(deployDAOFixture);

    const uri = "ipfs://market";
    const name = "Market NFT";
    const description = "Desc";
    const imagePath = "img";

    await daoNFT.connect(proposer).proposeNFT(uri, name, description, imagePath);
    await daoNFT.connect(voter1).voteForNFT(1);
    await daoNFT.connect(voter2).voteForNFT(1);

    await daoNFT.connect(proposer).sellNFT(0, 100);
    await paymentToken.connect(buyer).approve(await daoNFT.getAddress(), 100);

    await expect(daoNFT.connect(buyer).buyNFT(0))
      .to.emit(daoNFT, "NFTSold")
      .withArgs(0, buyer.address, 100);
  });

  it("Should return user NFTs correctly", async function () {
    const { daoNFT, voter1, voter2, proposer } = await loadFixture(deployDAOFixture);

    await daoNFT.connect(proposer).proposeNFT("ipfs://a", "a", "a", "a");
    await daoNFT.connect(proposer).proposeNFT("ipfs://b", "b", "b", "b");

    await daoNFT.connect(voter1).voteForNFT(1);
    await daoNFT.connect(voter2).voteForNFT(1); // mint 1-й

    const [minted, proposed] = await daoNFT.getUserNFTs(proposer.address);
    expect(minted.length).to.equal(1);
    expect(proposed.length).to.equal(1);
  });
});
