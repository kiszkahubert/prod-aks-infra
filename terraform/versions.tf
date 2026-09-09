terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "tfstateprodkiszka"
    container_name       = "tfstate"
    key                  = "aks-prod.tfstate"
    use_azuread_auth     = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }
  required_version = "~> 1.15.0"
}

provider "azurerm" {
  features {}

  resource_providers_to_register = [
    "Microsoft.ContainerService",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry",
    "Microsoft.Network",
    "Microsoft.Compute",
    "Microsoft.ManagedIdentity",
    "Microsoft.Authorization",
    "Microsoft.Insights",
  ]
}

provider "random" {}