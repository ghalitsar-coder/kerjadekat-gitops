# ==========================================
# Stage 1: Build (Bun + Vite)
# ==========================================
FROM oven/bun:1.1 AS builder

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

# KERJADEKAT_API_BASE is set to /api/v1 so all API calls are relative.
# Kong Ingress routes /api/* to the backend service at the cluster level.
ARG KERJADEKAT_API_BASE=/api/v1
ENV KERJADEKAT_API_BASE=${KERJADEKAT_API_BASE}

RUN bun run build

# ==========================================
# Stage 2: Serve (nginx)
# ==========================================
FROM nginx:1.27-alpine

WORKDIR /usr/share/nginx/html

# Remove default nginx static assets
RUN rm -rf ./*

# Copy built SPA
COPY --from=builder /app/dist .

# Copy custom nginx config (SPA routing + security headers)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
