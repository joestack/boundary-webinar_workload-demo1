provider "vault" {
  address   = local.vault_cluster_addr
  namespace = local.vault_namespace
  token     = local.vault_admin_token
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_generic_endpoint" "adm-user" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${var.vault_adm_user}"
  ignore_absent_fields = true

    data_json = data.template_file.user.rendered
}

data "template_file" "user" {
  template = file("${path.root}/templates/user.tpl") 
  vars = {
    policy = vault_policy.admins.name
    password = var.vault_adm_password
  }
}

resource "vault_policy" "admins" {
  name = "vault-admins"

  policy = <<EOT

# Allow managing leases
path "sys/leases/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage auth backends broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete auth backends
path "sys/auth/*"
{
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# List existing policies
path "sys/policies"
{
  capabilities = ["read"]
}

# Create and manage ACL policies broadly across Vault
path "sys/policies/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret backends broadly across Vault.
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secret engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# Read health checks
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

EOT
}

resource "tls_private_key" "signing-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vault_mount" "ssh-client-signer" {
  type        = "ssh"
  path        = "ssh-client-signer"
  description = "SSH mount"
}

resource "vault_ssh_secret_backend_ca" "ssh-client-signer-ca" {
  backend              = vault_mount.ssh-client-signer.path
  generate_signing_key = false
  public_key           = tls_private_key.signing-key.public_key_openssh
  private_key          = tls_private_key.signing-key.private_key_openssh
}

resource "vault_policy" "boundary-controller" {
  name = "boundary-controller"

  policy = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "ssh" {
  name   = "ssh"

  policy = <<EOT
path "ssh-client-signer/issue/boundary-client" {
  capabilities = ["create", "update"]
}
path "ssh-client-signer/sign/boundary-client" {
  capabilities = ["create", "update"]
}
EOT
}

//This isn't required for injected credentials, but would be required for brokered
resource "vault_policy" "kv-policy" {
  name   = "kv-read"
  policy = <<EOT
path "kv/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

resource "vault_ssh_secret_backend_role" "boundary-client" {
  name                    = "boundary-client"
  backend                 = vault_mount.ssh-client-signer.path
  key_type                = "ca"
  allow_user_certificates = true
  allow_host_certificates = true
  #default_user	          = "root"
  default_user	          = "ubuntu"
  allowed_users           = "*"
  allowed_extensions      = "*"
  default_extensions      = {
    "permit-pty" = ""
  }
}

resource "vault_token_auth_backend_role" "boundary_role" {
  role_name              = "boundary_role"
  allowed_policies       = [vault_policy.boundary-controller.name, vault_policy.kv-policy.name, vault_policy.ssh.name]
  #disallowed_policies    = ["default"]
  allowed_entity_aliases = []
  orphan                 = true
  token_period           = "86400"
  renewable              = true
  #token_explicit_max_ttl = ""
  path_suffix            = "path-suffix"
}

resource "vault_token" "boundary-credentials-store-token" {
  role_name         = "boundary_role"
  no_default_policy = true
  #policies          = ["boundary-controller", "ssh", "cred"]
  policies          = [vault_policy.boundary-controller.name, vault_policy.kv-policy.name, vault_policy.ssh.name]
  renewable         = true
  period            = "24h"
  no_parent         = true
  ttl               = "24h"

  renew_min_lease = 43200
  renew_increment = 86400

  metadata = {
    "purpose" = "boundary-service-account"
  }
  depends_on = [
    vault_token_auth_backend_role.boundary_role
  ]

}
