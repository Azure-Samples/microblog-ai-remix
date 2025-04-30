# ------------------------------
# Stage 1: Build the application
# ------------------------------
FROM node:20-alpine AS builder

# Set development environment
ENV NODE_ENV=development
WORKDIR /app

# Copy package files for better caching
COPY package*.json ./
COPY server/package*.json ./server/

# Install all dependencies
RUN npm install
RUN cd server && npm install

# Copy the entire source code
COPY . .

# Build Remix application first
RUN npm run build

# Build the server separately (keeping the working directory correct)
WORKDIR /app/server
RUN npm run clean && \
    mkdir -p dist && \
    cp -r src/* dist/ && \
    npm run build

# ------------------------------
# Stage 2: Runtime
# ------------------------------
FROM node:20-alpine AS runtime

ENV NODE_ENV=production
ENV PORT=80
WORKDIR /app

# Install production dependencies
COPY package*.json ./
COPY server/package*.json ./server/
RUN npm install --omit=dev
RUN cd server && npm install --omit=dev

# Copy build artifacts
COPY --from=builder /app/build ./build
COPY --from=builder /app/server/dist ./server/dist
COPY --from=builder /app/public ./public

EXPOSE 80
CMD ["node", "server/dist/index.js"]