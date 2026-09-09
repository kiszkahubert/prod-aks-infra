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

variable "workload_identities" {
  description = "Map of application which will be assigned its own Workload Identity"
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {}
}