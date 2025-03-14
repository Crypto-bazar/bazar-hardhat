import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      chainId: 1337,
      // accounts: {
      //   mnemonic: process.env.SEED_PHRASE
      // }
    }
  }
};

export default config;
