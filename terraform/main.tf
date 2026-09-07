data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length = 4
  special = false
  upper = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-dev-weu-01"
  location = "West US"
}

resource "azurerm_virtual_network" "vnet-01" {
  name                = "vnet-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-subnet-dev-weu-01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-01.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "bastion-subnet" {
  name                 = "bastion-subnet-dev-weu-01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-01.name
  address_prefixes     = ["10.0.2.0/28"]
}

# Idea was to create those subnets resources in them and use Private Endpoints but cost is high and also ACR supports private communication only in highest SKU
# resource "azurerm_subnet" "acr-subnet" {
#   name                 = "acr-subnet-dev-weu-01"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet-01.name
#   address_prefixes     = ["10.0.3.0/28"]
# }

resource "azurerm_subnet" "kv-subnet" {
  name                 = "kv-subnet-dev-weu-01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-01.name
  address_prefixes     = ["10.0.4.0/28"]
}

resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "bastion-nsg-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "allow-admin-ip-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_ips
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "explicit-deny-all-inbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https-outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http-outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-dns-outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ntp-outbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "123"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "explicit-deny-all-outbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion_nsg_asc" {
  subnet_id                 = azurerm_subnet.bastion-subnet.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}

resource "azurerm_network_security_group" "aks-nsg" {
  name                = "aks-nsg-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "allow-aks-internal-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.aks-subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-to-aks-inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.bastion-subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-lb-inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg_asc" {
  subnet_id                 = azurerm_subnet.aks-subnet.id
  network_security_group_id = azurerm_network_security_group.aks-nsg.id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "aks-dev-weu-01"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  dns_prefix              = "aks"
  oidc_issuer_enabled     = true
  private_cluster_enabled = true
  local_account_disabled  = true

  default_node_pool {
    name            = "system"
    node_count      = 1
    vm_size         = "Standard_D2ads_v6"
    os_disk_type    = "Ephemeral"
    os_disk_size_gb = 30
    vnet_subnet_id  = azurerm_subnet.aks-subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    service_cidr = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    pod_cidr = "10.2.0.0/16"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "acrdevweu01${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_key_vault" "kv" {
  name                          = "kv-dev-weu-01"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  enabled_for_disk_encryption   = true
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "kv_admin_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_aks_csi" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_public_ip" "pip" {
  name                = "bastion-pip-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "bastion-vm-nic" {
  name                = "bastion-vm-nic-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "base"
    subnet_id                     = azurerm_subnet.bastion-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_linux_virtual_machine" "bastion-vm" {
  name                            = "bastion-vm-dev-weu-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s_v2"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.bastion-vm-nic.id]
  admin_username                  = "bastionadmin"

  admin_ssh_key {
    username   = "bastionadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                = "kv-dns-link-dev-weu-01"
  private_dns_zone_id = azurerm_private_dns_zone.kv.id
  virtual_network_id  = azurerm_virtual_network.vnet-01.id
}

resource "azurerm_private_endpoint" "kv" {
  name                = "kv-pe-dev-weu-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.kv-subnet.id

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}