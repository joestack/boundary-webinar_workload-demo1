variable "tfc_state_org" {
  description = "TFC Organization where to access remote_state from"
  default = "JoeStack"
}

variable "rs_platform_hcp" {
  description = "TFC Workspace where to consume outputs from (cluster_url)"
  default = "boundary-webinar_platform-hcp"
}

variable "boundary_global_username" {
  description = "Terraform boundary_provider Username"
  }

variable "boundary_global_password" {
  description = "Terraform boundary_provider Password"
}

variable "boundary_project_username" {
  description = "Terraform boundary_provider Username"
}

variable "boundary_project_password" {
  description = "Terraform boundary_provider Password"
}

variable "vault_adm_user" {
  description = "Additinal non-root Username to access Vault"
}

variable "vault_adm_password" {
  description = "non-root Password to access Vault" 
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "name" {
  description = "Unique name of the deployment"
}

variable "instance_type" {
  description = "instance size to be used for worker nodes"
  default     = "t2.small"
}

variable "ssh_user" {
  description = "default ssh user to get access to an instance"
  default     = "ubuntu"
}

variable "pub_key" {
  description = "the public key to be used to access the bastion host and ansible nodes"
  default     = "joestack"
}

variable "pri_key" {
  description = "the base64 encoded private key to be used to access the bastion host and ansible nodes"
}

variable "web_node_count" {
  description = "number of workers (web-nodes)"
  default     = "5"
}

variable "db_node_count" {
  description = "number of worker (db-nodes)"
  default     = "5"
}

variable "web_subnet_count" {
  description = "number of subnets to be used for worker nodes"
  default     = "2"
}

variable "network_address_space" {
  description = "CIDR for this deployment"
  default     = "192.168.0.0/16"
}

variable "mysql_user" {
  description = "Username to be used to access the mysql DB"
  default     = "boundary"
}

variable "mysql_password" {
  description = "Password to be used to access the mysql DB"
  default     = "boundary1234!"
}