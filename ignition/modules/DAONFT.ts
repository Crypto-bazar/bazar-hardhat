// scripts/deploy.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "ethers";

const DAOModule = buildModule("DAOModule", (m) => {
  const initialSupply = m.getParameter("initialSupply", 1_000_000);
  const requiredVotes = m.getParameter("requiredVotes", parseUnits("1000", 18));

  const voter1 = m.getParameter("voter1", "0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
  const voter2 = m.getParameter("voter2", "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC");
  const voter3 = m.getParameter("voter3", "0x90F79bf6EB2c4f870365E785982E1f101E93b906");
  const voter4 = m.getParameter("voter4", "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65");

  const daoToken = m.contract("DAOToken", [initialSupply]);

  // ✅ Уникальные ID для каждого вызова
  m.call(daoToken, "transfer", [voter1, parseUnits("100", 18)], {
    after: [daoToken],
    id: "TransferToVoter1",
  });

  m.call(daoToken, "transfer", [voter2, parseUnits("200", 18)], {
    after: [daoToken],
    id: "TransferToVoter2",
  });

  m.call(daoToken, "transfer", [voter3, parseUnits("300", 18)], {
    after: [daoToken],
    id: "TransferToVoter3",
  });

  m.call(daoToken, "transfer", [voter4, parseUnits("400", 18)], {
    after: [daoToken],
    id: "TransferToVoter4",
  });

  const daoNFT = m.contract("DAONFT", [daoToken], { after: [daoToken] });

  return { daoToken, daoNFT };
});

export default DAOModule;
