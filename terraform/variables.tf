variable "admin_ips" {
  type        = list(string)
  description = "Allowed admin IPs to connect to bastion host"
}

variable "aks_admin_group_object_id" {
  type        = string
  description = "Entra ID AKS admins group Object ID"
}

variable "kv_secret_admin_group_object_id" {
  type        = string
  description = "Entra ID Key Vault admins group Object ID"
}

variable "location" {
  description = "Location to deploy resources to"
  type        = string
  default     = "West Europe"
}