variable "grafana_admin_password" {
  description = "Password for the grafana admin user."
  type        = string
}

variable "domain" {
  description = "Domain name for the grafana ingress path."
  type        = string
  default     = "kube-ssh-key"
}

variable "config_path" {
  type = string
}