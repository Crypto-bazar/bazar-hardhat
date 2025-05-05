#!/bin/sh

echo "Удаление старой сети"
pkill -f "hardhat node"

# Удаляем предыдущие деплойменты
echo "🧹 Удаление старых деплойментов..."
rm -rf ./ignition/deployments

# Запускаем hardhat node в фоне
echo "🚀 Запуск hardhat node..."
npx hardhat node >hardhat.log 2>&1 &

# Сохраняем PID, чтобы потом при желании убить
HARDHAT_PID=$!

# Ждём пока локальный нод поднимется (ищем ключевую строку в логе)
echo "⏳ Ожидание запуска узла..."
until grep -q "Started HTTP and WebSocket JSON-RPC server at http://127.0.0.1:8545/" hardhat.log; do
  sleep 1
done

echo "✅ Узел запущен. Выполняем деплой..."

# Деплой ignition-модуля
npx hardhat ignition deploy ./ignition/modules/DAONFT.ts --network localhost

# Всё!
echo "🏁 Скрипт завершён"
