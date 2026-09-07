variable "admin_ips" {
  type        = list(string)
  description = "Allowed admin IPs to connect to bastion host"
}