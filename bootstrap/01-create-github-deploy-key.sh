#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${KV_NAME:-}" ]]; then
  echo "KV_NAME env variable not set" >&2
  exit 1
fi
SECRET_NAME="argocd-github-deploy-key"
KEY_PATH="/tmp/argocd-deploy-key"

if az account show &>/dev/null; then
  echo "No valid az account found"
  exit 1
fi

rm -f "$KEY_PATH" "$KEY_PATH.pub"
ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "argocd-readonly"

az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "$SECRET_NAME" \
  --file "$KEY_PATH"

echo -e "Deploy key: \t$(cat "$KEY_PATH.pub")"
shred -u "$KEY_PATH" 2>/dev/null || rm -f "$KEY_PATH"
