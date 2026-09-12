# Azure AKS hardened infrastructure
The goal of this project was to create production level infrastructure for Kubernetes cluster on Azure cloud platform. There are some limitations in proposed solution stemming from the used Azure subscription (e.g. limit to 4 vCPU).

## Tools and Security Controls
1. Kubernetes
2. Key Vault
3. Microsoft Entra Workload Identity
4. Azure RBAC
5. Bastion/jump-host
6. ArgoCD
7. Pod Security Admission
8. Kyverno policies
9. Terraform

## Infrastucture
Infrastructure has been provisioned using Terraform.....


az group create --name rg-tfstate-prod --location westeurope

az storage account create \
  --name tfstateprodkiszka \
  --resource-group rg-tfstate-prod \
  --location westeurope \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --https-only true

az storage container create \
  --account-name tfstateprodkiszka \
  --name tfstate \
  --auth-mode login

MY_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show --name tfstateprodkiszka --resource-group rg-tfstate-prod --query id -o tsv)

az role assignment create \
  --assignee "$MY_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"

# Entra ID

az ad group create --display-name "aks-admins" --mail-nickname "aks-admins"
az ad group create --display-name "kv-secrets-admins" --mail-nickname "kv-secrets-admins"

AKS_ADMIN_GROUP_ID=$(az ad group show --group "aks-admins" --query id -o tsv)
KV_ADMIN_GROUP_ID=$(az ad group show --group "kv-secrets-admins" --query id -o tsv)
MY_ID=$(az ad signed-in-user show --query id -o tsv)

az ad group member add --group "aks-admins" --member-id "$MY_ID"
az ad group member add --group "kv-secrets-admins" --member-id "$MY_ID"