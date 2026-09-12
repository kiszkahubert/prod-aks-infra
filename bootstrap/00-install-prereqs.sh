#!/usr/bin/env bash
set -euo pipefail

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm version

if ! command -v argocd &>/dev/null; then
  curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
  rm /tmp/argocd
fi
argocd version --client

if ! command -v jq &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y jq
fi
