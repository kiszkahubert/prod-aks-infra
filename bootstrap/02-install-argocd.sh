#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

kubectl create namespace argocd --dry-run=client -oyaml | kubectl apply -f -

# PSA CONFIG
kubectl label namespace argocd \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
CHART_VERSION="${CHART_VERSION:-10.8.4}"

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "$CHART_VERSION" \
  -f argocd-values.yml \
  --wait

echo "== Initial admin passwd =="
kubectl -n argocd get secret argocd-initial-admin-secret -ojsonpath='{.data.password}' | base64 -d
