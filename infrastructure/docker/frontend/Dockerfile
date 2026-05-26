# ==========================================
# KerjaDekat Frontend — Minikube-ready
# Pattern: TanStack Start SPA via vite preview
# Reference: voyage-planner Azure deployment
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies (full including devDeps — vite preview needs them)
COPY package.json bun.lock ./
# Use bun for faster install since the project uses bun.lock
RUN corepack enable && npm install -g bun && bun install --frozen-lockfile || bun install

COPY . .

# Build-time env vars (baked into client bundle by Vite)
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# Build SPA (cloudflare: false, ssr: false in vite.config.ts)
RUN bun run build

# ==========================================
# Stage 2: Serve via vite preview (like voyage-planner)
# ==========================================
FROM node:20-alpine

WORKDIR /app

# Copy full project (vite preview needs node_modules + dist + src for config resolution)
COPY --from=builder /app/package.json /app/bun.lock ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src ./src
COPY --from=builder /app/vite.config.ts ./vite.config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json

EXPOSE 3000

# vite preview serves the built SPA with proper SPA fallback routing
CMD ["npx", "vite", "preview", "--host", "0.0.0.0", "--port", "3000"]
