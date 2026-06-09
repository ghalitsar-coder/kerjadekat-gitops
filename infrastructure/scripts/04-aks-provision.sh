#!/usr/bin/env bash
# =============================================================================
# KerjaDekat — Azure AKS Lite Provisioning
# AKS Lite: hanya menjalankan frontend, backend, dan PostgreSQL/PostGIS.
# Registry: DockerHub, bukan ACR, karena ACR diblokir oleh policy Azure for Students.
# =============================================================================
set -euo pipefail

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RG:-kerjadekat-aks-rg}"
LOCATION="${AZURE_LOCATION:-eastus}"
AKS_CLUSTER="${AZURE_AKS_CLUSTER:-kerjadekat-aks}"
NODE_SIZE="${AZURE_NODE_SIZE:-Standard_B2s}"
NODE_COUNT="${AZURE_NODE_COUNT:-1}"
K8S_VERSION="${AZURE_K8S_VERSION:-1.29}"

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "[ERROR] Set AZURE_SUBSCRIPTION_ID terlebih dahulu."
  echo "        export AZURE_SUBSCRIPTION_ID=\$(az account show --query id -o tsv)"
  exit 1
fi

if ! az account show &>/dev/null; then
  echo "[ERROR] Belum login ke Azure. Jalankan: az login"
  exit 1
fi

az account set --subscription "${SUBSCRIPTION_ID}"

echo "=========================================="
echo " KerjaDekat — AKS Lite Provisioning"
echo "=========================================="
echo " Subscription : ${SUBSCRIPTION_ID}"
echo " Resource Group: ${RESOURCE_GROUP}"
echo " Location      : ${LOCATION}"
echo " AKS Cluster   : ${AKS_CLUSTER}"
echo " Node Size     : ${NODE_SIZE} x${NODE_COUNT}"
echo " Registry      : DockerHub (ghalitsar), no ACR"
echo "=========================================="
echo ""

echo "[1/4] Membuat/mengecek Resource Group..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table

echo "[2/4] Membuat AKS Cluster hemat biaya (tanpa ACR, tanpa monitoring addon)..."
az aks create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER}" \
  --node-count "${NODE_COUNT}" \
  --node-vm-size "${NODE_SIZE}" \
  --kubernetes-version "${K8S_VERSION}" \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --output table

echo "[3/4] Mengambil kubeconfig AKS..."
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER}" \
  --overwrite-existing

echo "[4/4] Menyimpan output ke infrastructure/scripts/.env.aks..."
cat > "$(dirname "$0")/.env.aks" <<EOF
AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
AZURE_RG=${RESOURCE_GROUP}
AZURE_LOCATION=${LOCATION}
AZURE_AKS_CLUSTER=${AKS_CLUSTER}
DOCKER_REGISTRY=docker.io
DOCKER_NAMESPACE=ghalitsar
EOF

echo ""
echo "=========================================="
echo " AKS LITE PROVISIONING SELESAI"
echo "=========================================="
echo " Context kubectl: $(kubectl config current-context)"
echo ""
echo " Lanjut:"
echo "   bash infrastructure/scripts/04b-push-images-to-dockerhub.sh"
echo "   bash infrastructure/scripts/05-aks-connect-argocd.sh"
