// scripts/deploy.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";

const DAONFTModule = buildModule("DAONFTModule", (m) => {
  // Параметры для токенов
  const initialSupply = m.getParameter("initialSupply", parseEther("1000000"));
  const tokenPrice = m.getParameter("tokenPrice", parseEther("0.000000000000000001"));
  const paymentTokenPrice = m.getParameter("paymentTokenPrice", parseEther("0.000000000000000001"));
  const requiredVotes = m.getParameter("requiredVotes", parseEther("10000"));

  // Деплой токенов
  const daoToken = m.contract("DAOToken", [initialSupply]);
  const paymentToken = m.contract("PaymentToken", [initialSupply]);

  // Деплой DAONFT контракта с нужными параметрами
  const daoNFT = m.contract("DAONFT", [
    daoToken,
    paymentToken,
    tokenPrice,
    paymentTokenPrice
  ], {
    after: [daoToken, paymentToken]
  });

  // Настройка распределения токенов для тестирования
  const testAccounts = [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
  ];

  // Распределение токенов между тестовыми аккаунтами
  // Массивы для хранения ссылок на вызовы transfer
  const daoTokenTransfers = testAccounts.map((account, index) => {
    const amount = parseEther((100 * (index + 1)).toString());
    return m.call(daoToken, "transfer", [account, amount], {
      after: [daoToken],
      id: `TransferDAOTokenTo${index}`
    });
  });

  const paymentTokenTransfers = testAccounts.map((account, index) => {
    const amount = parseEther((100 * (index + 1)).toString());
    return m.call(paymentToken, "transfer", [account, amount], {
      after: [paymentToken],
      id: `TransferPaymentTokenTo${index}`
    });
  });

  m.call(daoToken, "transfer", [daoNFT, parseEther("999000")], {
    after: daoTokenTransfers,
    id: "TransferRemainingDAOTokenToDAONFT"
  });

  m.call(paymentToken, "transfer", [daoNFT, parseEther("999000")], {
    after: paymentTokenTransfers,
    id: "TransferRemainingPaymentTokenToDAONFT"
  });


  return { daoToken, paymentToken, daoNFT };
});

export default DAONFTModule;