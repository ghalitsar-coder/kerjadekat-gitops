#!/usr/bin/env bash
# =============================================================================
# KerjaDekat — AKS ArgoCD Setup & GitOps Bootstrap
# =============================================================================
set -euo pipefail

# Repo URL for GitOps — Use AKS specific revision/overlay if needed
# For now we use the main repo, but we will apply the 'aks' overlay
REPO_URL="${GITOPS_REPO_URL:-https://github.com/ghalitsar-coder/kerjadekat-gitops}"

echo "=========================================="
echo " AKS GitOps Bootstrap"
echo "=========================================="
echo " Context: $(kubectl config current-context)"
echo ""

# 1. Install ArgoCD
echo "[1/4] Menginstall ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f \
  "https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.0/manifests/install.yaml"

echo "      Menunggu ArgoCD siap..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# 2. Get Admin Password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "      ArgoCD Admin: admin / ${ARGOCD_PASS}"

# 3. Setup Project & Root App
echo "[2/4] Setup AppProject..."
kubectl apply -f gitops/argocd/project.yaml -n argocd

# 4. Bootstrap overlay AKS.
# Berbeda dari Minikube, root app AKS langsung menunjuk ke gitops/overlays/aks
# agar image ACR, StorageClass AKS, dan Kong LoadBalancer dipakai.
echo "[3/4] Bootstrap Root Application AKS..."
kubectl apply -f gitops/argocd/root-application-aks.yaml -n argocd

# 5. Patch Service ArgoCD ke LoadBalancer agar bisa diakses eksternal (Opsional)
echo "[4/4] Membuka ArgoCD UI via LoadBalancer..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo ""
echo "=========================================="
echo " AKS GITOP SETUP SELESAI!"
echo "=========================================="
echo ""
echo " Tunggu 1-2 menit hingga Azure LoadBalancer menyediakan IP Publik."
echo " Ambil IP ArgoCD:"
echo "   kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""
echo " Ambil IP Kong Proxy (Aplikasi Anda):"
echo "   kubectl get svc kong-kong-proxy -n kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""
echo " Password ArgoCD: ${ARGOCD_PASS}"
echo ""
