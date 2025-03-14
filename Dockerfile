# Используем официальный образ Node.js
FROM node:slim

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем package.json и package-lock.json
COPY package*.json ./

# Устанавливаем зависимости проекта
RUN npm install

# Копируем все остальные файлы проекта
COPY . .

# Открываем порт для взаимодействия с сетью
EXPOSE 8545

# Устанавливаем команду для запуска сети
CMD ["npx", "hardhat", "node"]
