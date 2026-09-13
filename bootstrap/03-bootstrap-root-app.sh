#!/usr/bin/env bash
set -euo pipefail

: "${KV_NAME:?KV_MAME is not set}"
: "${AKS_RG:?AKS_RG is not set}"
: "${AKS_NAME:?AKS_NAME is not set}"
: "${GITHUB_REPO:?GITHUB_REPO is not set (org-name/repo-name)"

TENANT_ID=$(az account show --query tenantID -otsv)
CSI_CLIENT_ID=$(az aks show -g "$AKS_RG" -n "AKS_NAME" --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -otsv)
TMP=$(mktemp)
sed -e "s|<KV_NAME>|$KV_NAME|g" \
    -e "s|<TENANT_ID>|$TENANT_ID|g" \
    -e "s|<AKS_KV_CSI_CLIENT_ID>|$CSI_CLIENT_ID|g" \
    -e "s|<GITHUB_ORG>/<GITHUB_REPO>|$GITHUB_REPO|g" \
    secrets/argocd-repo-secretproviderclass.yml > "$TMP"

kubectl apply -f "$TMP"
rm -f "$TMP"

echo "Waiting for CSI driver to sync secret"
kubectl -n argocd wait --for=condition=Ready pod/kv-sync-trigger --timeout=300s
kubectl -n argocd delete pod kv-sync-trigger --ignore-not-found
