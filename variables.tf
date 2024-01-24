variable "tfc_state_org" {
  description = "TFC Organization where to access remote_state from"
  default = "JoeStack"
}

variable "rs_platform_hcp" {
  description = "TFC Workspace where to consume outputs from (cluster_url)"
  default = "boundary-webinar_platform-hcp"
}

variable "boundary_global_username" {
  description = "Root credential to access Boundary UI and/or Terraform (global scope)"
  }

variable "boundary_global_password" {
  description = "Root credential to access Boundary UI and/or Terraform (global scope) "
}

variable "boundary_project_username" {
  description = "project scope credential"
}

variable "boundary_project_password" {
  description = "Project scope credential"
}

variable "vault_adm_user" {
  description = "Additinal non-root Username to access Vault with Username/Password"
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
  description = "default ssh user to get access to an instance."
  default     = "ubuntu"
}

variable "pub_key" {
  description = "the name of the public key that is already uploaded into your specific AWS region to be used to access the bastion host and worker nodes"
  default     = "joestack"
}

variable "pri_key" {
  description = "the base64 encoded private part of the pub_key to be used to access the worker nodes from the bastion host (the same key that you use to access the bastion host). "
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