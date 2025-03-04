# Stage 1: Build the application
FROM node:20-alpine AS builder

# Set environment variables
ENV NODE_ENV=production

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY server/package*.json ./server/

# Install dependencies in root
RUN npm ci

# Install dependencies in server directory
WORKDIR /app/server
RUN npm ci
WORKDIR /app

# Copy the rest of the application code
COPY . .

RUN npm run build:all

# Stage 2: Run the application
FROM node:20-alpine AS runtime

# Set environment variables
ENV NODE_ENV=production

# Port exposed
ENV PORT=80

# create app directory
WORKDIR /app

COPY package*.json ./
COPY server/package*.json ./server/

# Install production dependencies
RUN npm ci --omit=dev

WORKDIR /app/server
RUN npm ci --omit=dev

WORKDIR /app

# Copy built application from build stage
COPY --from=builder /app/build ./build
COPY --from=builder /app/server/dist ./server/dist
COPY --from=builder /app/public ./public

EXPOSE 80

CMD [ "node", "server/dist/index.js"]
