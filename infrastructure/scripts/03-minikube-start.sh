#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " KerjaDekat — Minikube Cluster Bootstrap"
echo "=========================================="

minikube start \
  --cpus=6 \
  --memory=16384 \
  --disk-size=60g \
  --driver=docker \
  --kubernetes-version=v1.29.0

echo "--- Enabling required addons ---"
minikube addons enable metrics-server
minikube addons enable ingress

echo "--- Cluster info ---"
kubectl cluster-info
kubectl get nodes -o wide

echo ""
echo "Minikube IP: $(minikube ip)"
echo "Kong NodePort will be: http://$(minikube ip):30080"
echo ""
echo "Next step: run ./infrastructure/scripts/01-install-argocd.sh"
