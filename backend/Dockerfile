# StaySpot API (Express + Prisma + PostGIS)
FROM node:20-slim
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json ./
COPY src ./src
COPY scripts ./scripts
RUN npm run build
EXPOSE 3000
# Apply migrations on boot, then start
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/index.js"]
