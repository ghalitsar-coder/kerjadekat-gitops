#!/usr/bin/env bash
# =============================================================================
# KerjaDekat — Push Images to Azure Container Registry (ACR)
# Script ini build & push image lokal ke ACR yang baru dibuat.
# =============================================================================
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env.aks"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] File $ENV_FILE tidak ditemukan."
  echo "        Jalankan 04-aks-provision.sh terlebih dahulu."
  exit 1
fi
source "$ENV_FILE"

echo "=========================================="
echo " Push Images to ACR: ${ACR_LOGIN_SERVER}"
echo "=========================================="

echo "[1/4] Login ke ACR via Docker..."
# Login langsung via docker (lebih kompatibel di pipeline CI/CD)
echo "${ACR_PASSWORD}" | docker login "${ACR_LOGIN_SERVER}" --username "${ACR_USERNAME}" --password-stdin
# Atau jika di CLI lokal: az acr login --name ${AZURE_ACR_NAME}

echo "[2/4] Build & Push PostgreSQL PostGIS custom image..."
cd infrastructure/docker/postgres-postgis
docker build -t "${ACR_LOGIN_SERVER}/kerjadekat-postgres-postgis:17-3.5" .
docker push "${ACR_LOGIN_SERVER}/kerjadekat-postgres-postgis:17-3.5"
cd ../../../

echo "[3/4] Build & Push RabbitMQ Delayed custom image..."
cd infrastructure/docker/rabbitmq
docker build -t "${ACR_LOGIN_SERVER}/kerjadekat-rabbitmq-delayed:3.13" .
docker push "${ACR_LOGIN_SERVER}/kerjadekat-rabbitmq-delayed:3.13"
cd ../../../

# Opsional: Jika Anda ingin push versi awal frontend & backend:
# echo "[4/4] Retag & Push Backend & Frontend..."
# docker tag ghalitsar/kerjadekat-backend:latest ${ACR_LOGIN_SERVER}/kerjadekat-backend:latest
# docker push ${ACR_LOGIN_SERVER}/kerjadekat-backend:latest
# docker tag ghalitsar/kerjadekat-frontend:latest ${ACR_LOGIN_SERVER}/kerjadekat-frontend:latest
# docker push ${ACR_LOGIN_SERVER}/kerjadekat-frontend:latest

echo ""
echo "Semua image berhasil di-push ke ACR."
echo "Lanjut jalankan: bash infrastructure/scripts/05-aks-connect-argocd.sh"
