// scripts/deploy.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DAOModule = buildModule("DAOModule", (m) => {
  // Параметры для деплоя
  const initialSupply = m.getParameter("initialSupply", 1_000_000); // 1 млн токенов
  const requiredVotes = m.getParameter("requiredVotes", 1000 * 10**18); // 1000 токенов (с учетом decimals)

  // Деплой DAOToken
  const daoToken = m.contract("DAOToken", [initialSupply]);

  // Деплой DAONFT с передачей адреса DAOToken
  const daoNFT = m.contract("DAONFT", [daoToken], {
    after: [daoToken] // Указываем, что DAONFT должен деплоиться после DAOToken
  });

  // Возвращаем объекты контрактов для использования в других модулях
  return { daoToken, daoNFT };
});

export default DAOModule;