# ==========================================
# KerjaDekat Frontend — Minikube-ready
# TanStack Start SSR → SPA fallback via nginx
# ==========================================
FROM oven/bun:latest AS builder

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile || bun install

COPY . .

ARG KERJADEKAT_API_BASE=/api/v1
ENV KERJADEKAT_API_BASE=${KERJADEKAT_API_BASE}

# Build client + server bundles
RUN bun run build

# Generate index.html from built assets dynamically
RUN node -e " \
  const fs = require('fs'); \
  const path = require('path'); \
  const assetsDir = 'dist/client/assets'; \
  const cssFiles = fs.readdirSync(assetsDir).filter(f => f.endsWith('.css')); \
  const jsFiles = fs.readdirSync(assetsDir).filter(f => f.startsWith('index-') && f.endsWith('.js')); \
  const jsSizes = jsFiles.map(f => ({name: f, size: fs.statSync(path.join(assetsDir, f)).size})); \
  jsSizes.sort((a,b) => b.size - a.size); \
  const mainEntry = jsSizes[0]?.name || ''; \
  const routeManifest = jsSizes[1]?.name || ''; \
  const cssLinks = cssFiles.map(f => '<link rel=\"stylesheet\" href=\"/assets/' + f + '\"/>').join('\n    '); \
  const html = '<!DOCTYPE html>\n<html lang=\"id\">\n<head>\n' + \
    '    <meta charset=\"UTF-8\"/>\n    <meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\"/>\n' + \
    '    <title>KerjaDekat</title>\n    <link rel=\"manifest\" href=\"/manifest.webmanifest\"/>\n' + \
    '    ' + cssLinks + '\n' + \
    '    <script type=\"module\" crossorigin src=\"/assets/' + mainEntry + '\"></script>\n' + \
    (routeManifest ? '    <script type=\"module\" crossorigin src=\"/assets/' + routeManifest + '\"></script>\n' : '') + \
    '</head>\n<body>\n    <div id=\"root\"></div>\n</body>\n</html>\n'; \
  fs.writeFileSync('dist/client/index.html', html); \
  console.log('Generated index.html with entry:', mainEntry); \
"

# ==========================================
# Stage 2: Serve (nginx)
# ==========================================
FROM nginx:1.27-alpine

WORKDIR /usr/share/nginx/html
RUN rm -rf ./*

COPY --from=builder /app/dist/client .

# Write nginx config using printf (heredoc not supported in legacy builder)
RUN printf 'server {\n\
    listen 80;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|map|webmanifest)$ {\n\
        expires 1y;\n\
        add_header Cache-Control "public, immutable";\n\
        access_log off;\n\
    }\n\
    add_header X-Frame-Options SAMEORIGIN always;\n\
    add_header X-Content-Type-Options nosniff always;\n\
    add_header X-XSS-Protection "1; mode=block" always;\n\
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;\n\
    gzip on;\n\
    gzip_types text/plain text/css application/javascript application/json\n\
               application/x-javascript text/xml application/xml\n\
               application/xml+rss text/javascript image/svg+xml;\n\
    gzip_min_length 256;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
