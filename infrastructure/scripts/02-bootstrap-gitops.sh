#!/usr/bin/env bash
set -euo pipefail

# Set your Git repo URL here or export GITOPS_REPO_URL before running
REPO_URL="${GITOPS_REPO_URL:-https://github.com/YOUR_ORG/kerjadekat}"

echo "=========================================="
echo " KerjaDekat — GitOps Bootstrap (ONE-TIME)"
echo "=========================================="
echo "Using Git repo: ${REPO_URL}"
echo ""

# Patch the root-application.yaml with the correct repo URL
sed -i "s|https://github.com/YOUR_ORG/kerjadekat|${REPO_URL}|g" \
  gitops/argocd/root-application.yaml
sed -i "s|https://github.com/YOUR_ORG/kerjadekat|${REPO_URL}|g" \
  gitops/argocd/project.yaml

echo "--- Applying ArgoCD AppProject ---"
kubectl apply -f gitops/argocd/project.yaml -n argocd

echo "--- Applying Root Application (App-of-Apps) ---"
kubectl apply -f gitops/argocd/root-application.yaml -n argocd

echo ""
echo "Bootstrap complete!"
echo "ArgoCD will now pull and sync all child applications from Git."
echo ""
echo "Watch sync progress:"
echo "  kubectl get applications -n argocd -w"
echo ""
echo "Or open the ArgoCD UI (see 01-install-argocd.sh output for URL)"
