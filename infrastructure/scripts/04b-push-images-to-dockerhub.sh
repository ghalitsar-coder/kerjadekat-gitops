#!/usr/bin/env bash
# =============================================================================
# Push image custom (PostGIS) ke DockerHub
# =============================================================================
set -euo pipefail

echo "=========================================="
echo " Push Images to DockerHub"
echo "=========================================="

echo "[1/2] Pastikan Anda sudah login DockerHub (docker login)..."

echo "[2/2] Build & Push PostgreSQL PostGIS..."
cd infrastructure/docker/postgres-postgis
docker build -t "ghalitsar/kerjadekat-postgres-postgis:17-3.5" .
docker push "ghalitsar/kerjadekat-postgres-postgis:17-3.5"
cd ../../../

echo ""
echo "Selesai. Lanjut jalankan: bash infrastructure/scripts/05-aks-connect-argocd.sh"
