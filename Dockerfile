# ------------------------------
# 1) Frontend Build (Remix)
# ------------------------------
FROM node:20-alpine AS frontend
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json remix.config.js vite.config.ts ./
COPY app ./app
COPY public ./public

# Build do Frontend - Remix
RUN npm run build

# ------------------------------
# 2) Backend Build (Express + TS)
# ------------------------------
FROM node:20-alpine AS backend
WORKDIR /server

COPY server/. .

RUN npm install \
 && npm run clean \
 && npm run build

# ------------------------------
# 3) Image Production
# ------------------------------

FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=80

COPY package.json ./
COPY server/package.json ./server/
RUN npm install --omit=dev \
  && cd server && npm install --omit=dev

# Frontend
COPY --from=frontend /app/build ./build
COPY --from=frontend /app/public ./public

# Backend
COPY --from=backend /server/dist ./server/dist

EXPOSE 80
CMD ["node", "server/dist/index.js"]
