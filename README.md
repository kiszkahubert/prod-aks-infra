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

## Init steps
Infrastructure has been provisioned using Terraform which is an IaC tool allowing for repeatable and quick provisioning from configuration file. To achieve best prod standards state file has been stored in remote backend (Azure Storage Account) utilizing commands bellow. 

```
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
```
However storage account has two planes - **Control plane** which is used to manage storage accounts, it does not need any role to access other than Owner or Contributor on subscription or resource group level. There is also **Data plane** which is used to acess data inside the Storage Account, however it needs an additional role even if you are **Owner**. Needed role to assign is **Storage Blob Data Contributor**
```
MY_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ID=$(az storage account show --name tfstateprodkiszka --resource-group rg-tfstate-prod --query id -o tsv)

az role assignment create \
  --assignee "$MY_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"
```
This step has to be done manually as Terraform cannot provision something it needs in the first place to work.

## Limitations
Key idea was to create private AKS cluster and access it via bastion/jump host VM. Making cluster private has a lot of benefits. Main one is that kube-api cannot be directly called via public Internet as it only recieves private IP in the VNet. However there is still need of solution which would allow to communicate with cluster via **kubectl**. There are 3 possible ways to achieve that I am aware of:
1. **VPN (Point-to-Site)** - Allows to connect PC with AKS VNet, convenient but requires configuration of Virtual Network Gateway
2. **Azure Bastion or Jump host VM** - You can either use managed Azure service called Azure Bastion or create your own VM which would work as Jump host which is a commonly used on-prem pattern which I have also at first implemented in my solution
3. **az aks command invoke** - kubectl command is being executed by ARM in cluster - there is no need of VPN or jump host you can send commands from your local host, but the main disadvantage is that its painfully slow as it needs to first create pod in the cluster execute command then delete pod and come back with response.

As I have used jump host pattern previously I have decided to use it again this time. However there is a problem - Azure allows to extend vCPU limit only for pay-as-you-go subscription. As I am on different subscription I have a hard cap of 4 vCPU though I have decided to go for it. Ive created AKS cluster with only one system node which use 2 vCPU and then created jump host utilizing other 2 vCPU. Everything was fine until I have installed ArgoCD, kyverno and my pods were constantly OOMKILLED as the node had high CPU usage and also there were no room to schedule new pods as requests were maxed out (Will elaborate on that later). So I had to opt out of the jump host idea to regain back 2 vCPU which allowed me to create an additional user nodepool for AKS. However after getting rid of jump host I had no way to communicate with Kubernetes cluster. That is why I have decided to go for the simplest solution which was to use **az aks command invoke**.   
## Infrastructure
Every resource that needs an IP address will be created in one of three subnets based on its purpose. Main VNET has address space of 10.0.0.0/16. There are 3 subnets used in the proposed solution
|Name|Address space|Purpose|
|----------|-------------|-------|
|aks-subnet|10.0.1.0/24|Pool of addresses assigned to nodepools|
|bastion-subnet| 10.0.2.0/28|Pool of addresses assigned to bastion hosts|
|kv-subnet|10.0.4.0/28|Pool of addresses assigned to Key Vault|

 

# Entra ID

az ad group create --display-name "aks-admins" --mail-nickname "aks-admins"
az ad group create --display-name "kv-secrets-admins" --mail-nickname "kv-secrets-admins"

AKS_ADMIN_GROUP_ID=$(az ad group show --group "aks-admins" --query id -o tsv)
KV_ADMIN_GROUP_ID=$(az ad group show --group "kv-secrets-admins" --query id -o tsv)
MY_ID=$(az ad signed-in-user show --query id -o tsv)

az ad group member add --group "aks-admins" --member-id "$MY_ID"
az ad group member add --group "kv-secrets-admins" --member-id "$MY_ID"

# BASTION
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az aks install-cli
az login --identity
az account set --subscription dd089afc-a56d-413b-828b-1867bda4beef
az aks get-credentials \
  --resource-group rg-dev-weu-01 \
  --name aks-dev-weu-01 \
  --overwrite-existing
kubelogin convert-kubeconfig -l msi