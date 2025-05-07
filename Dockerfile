# ------------------------------
# Stage 1: Build the application
# ------------------------------
  FROM node:20-alpine AS builder

  # Definimos NODE_ENV=development para garantir que devDependencies sejam instaladas
  ENV NODE_ENV=development
  WORKDIR /app
  
  # Copia somente os arquivos de pacote, para aproveitar cache de build
  COPY package*.json ./
  COPY server/package*.json ./server/
  
  # Instala todas as dependências (prod + dev)
  RUN npm install
  
  # Copia todo o restante do código
  COPY . .
  
  # Executa o build (Remix + Tailwind + etc.)
  RUN npm run build:all
  
  # ------------------------------
  # Stage 2: Runtime
  # ------------------------------
  FROM node:20-alpine AS runtime
  
  ENV NODE_ENV=production
  ENV PORT=80
  WORKDIR /app
  
  # Copiamos os package.jsons para instalar apenas as dependências de produção
  COPY package*.json ./
  COPY server/package*.json ./server/
  RUN npm install --omit=dev
  
  # Copiamos do “builder” somente os artefatos gerados e o que for preciso
  COPY --from=builder /app/build ./build
  COPY --from=builder /app/server/dist ./server/dist
  COPY --from=builder /app/public ./public
  
  EXPOSE 80
  CMD [ "node", "server/dist/index.js" ]
  