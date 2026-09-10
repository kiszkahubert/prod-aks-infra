output "bastion_vm_ip" {
  value = azurerm_public_ip.pip.ip_address
}