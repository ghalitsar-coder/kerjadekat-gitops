#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v2.13.0"

echo "--- Installing ArgoCD ${ARGOCD_VERSION} ---"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "--- Waiting for ArgoCD to be ready (up to 5 min) ---"
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

echo ""
echo "ArgoCD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8081:80"
echo "  then open: http://localhost:8081  (user: admin)"
echo ""
echo "Next step: run ./infrastructure/scripts/02-bootstrap-gitops.sh"
