#!/usr/bin/env bash
set -euo pipefail

: "${KV_NAME:?KV_MAME is not set}"
: "${AKS_RG:?AKS_RG is not set}"
: "${AKS_NAME:?AKS_NAME is not set}"

TENANT_ID=$(az account show --query tenantID -otsv)
CSI_CLIENT_ID=$(az aks show -g "$AKS_RG" -n "AKS_NAME" --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -otsv)
TMP=$(mktemp)
sed -e "s|<KV_NAME>|$KV_NAME|g" \
    -e "s|<TENANT_ID>|$TENANT_ID|g" \
    -e "s|<AKS_KV_CSI_CLIENT_ID>|$CSI_CLIENT_ID|g" \
    secrets/argocd-repo-secretproviderclass.yml > "$TMP"

kubectl apply -f "$TMP"
rm -f "$TMP"