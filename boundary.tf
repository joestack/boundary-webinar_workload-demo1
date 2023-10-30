provider "boundary" {
  #alias = "global"
  addr                   = local.boundary_cluster_addr
  auth_method_login_name = var.boundary_global_username
  auth_method_password   = var.boundary_global_password
}

# provider "boundary" {
#   alias                  = "project"
#   addr                   = local.boundary_cluster_addr
#   auth_method_login_name = var.boundary_project_username
#   auth_method_password   = var.boundary_project_password
#   scope_id               = local.demo_org_id
# }

resource "boundary_scope" "global" {
  global_scope = true
  scope_id     = "global"
}

resource "boundary_scope" "org" {
  name                     = "Webinar Org"
  description              = "Dedicated scope for Webinars"
  scope_id                 = boundary_scope.global.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_auth_method" "password" {
  scope_id = boundary_scope.org.id
  type     = "password"
}

resource "boundary_account_password" "user" {
  auth_method_id = boundary_auth_method.password.id
  login_name = var.boundary_project_username
  password   = var.boundary_project_password
}

resource "boundary_user" "user" {
  name        = var.boundary_project_username
  description = "${var.boundary_project_username}'s user resource"
  account_ids = [boundary_account_password.user.id]
  scope_id    = boundary_scope.org.id
}

resource "boundary_scope" "project" {
  name                   = "Boundary Webinar"
  description            = "Boundary Project within Webinar's Org scope!"
  scope_id               = boundary_scope.org.id
  auto_create_admin_role = true
}

resource "boundary_role" "project_admin" {
  name          = "project_admin"
  description   = "Admin role within Demo Project"
  principal_ids = [boundary_user.user.id]
  grant_strings = ["id=*;type=*;actions=*"]
  scope_id      = boundary_scope.project.id
}

resource "boundary_worker" "controller_led" {
  scope_id    = boundary_scope.org.id
  name        = "worker 1"
  description = "self managed worker with controller led auth"
}

//Credential store Static
resource "boundary_credential_store_static" "example" {
  name        = "boundary-credential-store"
  description = "Internal Static Credential Store!"
  scope_id    = boundary_scope.project.id
}

resource "boundary_credential_ssh_private_key" "example" {
  name                = "webnodes"
  description         = "SSH Private Key for webnodes"
  #credential_store_id = boundary_credential_store_static.example.id
  credential_store_id = boundary_credential_store_static.example.id
  username            = "ubuntu"
  private_key         = local.priv_key
  #private_key_passphrase = "optional-passphrase" # change to the passphrase of the Private Key if required
}

//Credential store Vault
resource "boundary_credential_store_vault" "vault_cred_store_dyn" {
  name        = "vault-credential-store"
  description = "Vault Dynamic Credential Store"
  address     = local.vault_cluster_addr
  token       = vault_token.boundary-credentials-store-token.client_token
  namespace   = local.vault_namespace
  scope_id    = boundary_scope.project.id
}

resource "boundary_credential_library_vault_ssh_certificate" "vault" {
  name                = "certificates-library"
  description         = "Vault CA to grant access to dbnodes"
  #credential_store_id = boundary_credential_store_vault.vault_cred_store_dyn.id
  credential_store_id = boundary_credential_store_vault.vault_cred_store_dyn.id
  path                = "ssh-client-signer/sign/boundary-client"
  username            = "ubuntu"
  key_type            = "ecdsa"
  key_bits            = 521
  extensions          = {
    permit-pty = ""
  }
}


resource "boundary_target" "ssh_hosts" {
  name                     = "ssh-static-injection-webnodes"
  description              = "ssh webnode targets"
  type                     = "ssh"
  default_port             = "22"
  scope_id                 = boundary_scope.project.id
  ingress_worker_filter    = "\"worker1\" in \"/tags/type\""
  enable_session_recording = false
  #storage_bucket_id                          = boundary_storage_bucket.session-storage.id
  host_source_ids = [
    boundary_host_set_static.set.id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.example.id
  ]
}

resource "boundary_host_catalog_static" "catalog" {
  name        = "webnodes-catalog"
  description = "My webnodes catalog"
  scope_id    = boundary_scope.project.id
}

resource "boundary_host_set_static" "set" {
  type            = "static"
  name            = "webnodes-host-set"
  host_catalog_id = boundary_host_catalog_static.catalog.id
  host_ids        = boundary_host_static.servers.*.id
}
resource "boundary_host_static" "servers" {
  count           = var.web_node_count
  type            = "static"
  name            = aws_instance.web_nodes.*.tags[count.index]["Name"]
  host_catalog_id = boundary_host_catalog_static.catalog.id
  address         = element(aws_instance.web_nodes.*.private_ip, count.index)
}



resource "boundary_target" "ssh_hosts_db" {
  name                     = "ssh-dynamic-injection-dbnodes"
  description              = "ssh dbnode targets"
  type                     = "ssh"
  default_port             = "22"
  scope_id                 = boundary_scope.project.id
  ingress_worker_filter    = "\"worker1\" in \"/tags/type\""
  enable_session_recording = false
  #storage_bucket_id       = boundary_storage_bucket.session-storage.id
  host_source_ids = [
    boundary_host_set_static.set_db.id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.vault.id
  ]
}

resource "boundary_host_catalog_static" "catalog_db" {
  name        = "db-catalog"
  description = "My dbnodes catalog"
  scope_id    = boundary_scope.project.id
}

resource "boundary_host_set_static" "set_db" {
  type            = "static"
  name            = "dbnodes-host-set"
  host_catalog_id = boundary_host_catalog_static.catalog_db.id
  host_ids        = boundary_host_static.servers_db.*.id
}
resource "boundary_host_static" "servers_db" {
  count           = var.web_node_count
  type            = "static"
  name            = aws_instance.db_nodes.*.tags[count.index]["Name"]
  host_catalog_id = boundary_host_catalog_static.catalog_db.id
  address         = element(aws_instance.db_nodes.*.private_ip, count.index)
}




# new
resource "boundary_account_password" "db-user" {
  auth_method_id = boundary_auth_method.password.id
  login_name = "db-user"
  password   = "db-password1234"
}

resource "boundary_user" "db-user" {
  name        = "db-user"
  description = "db-user's user resource"
  account_ids = [boundary_account_password.db-user.id]
  scope_id    = boundary_scope.org.id
}

resource "boundary_role" "db_admin" {
  name          = "db_admin"
  description   = "db-admin within Demo Project"
  principal_ids = [boundary_user.db-user.id]
  grant_strings = ["id=*;type=*;actions=*"]
  scope_id      = boundary_scope.project.id
}

//Credential store Static
resource "boundary_credential_store_static" "db" {
  name        = "db-credential-store"
  description = "Internal Static Credential Store for DB account!"
  scope_id    = boundary_scope.project.id
}

resource "boundary_credential_username_password" "db" {
  name                = "DB Credentials"
  description         = "My first username password credential!"
  credential_store_id = boundary_credential_store_static.db.id
  #credential_store_id = boundary_credential_store_static.example.id
  username            = "boundary"
  password            = "boundary1234!"
}

resource "boundary_target" "mysql_hosts" {
  name                     = "mysql"
  description              = "mysql target"
  type                     = "tcp"
  default_port             = "3306"
  scope_id                 = boundary_scope.project.id
  ingress_worker_filter    = "\"worker1\" in \"/tags/type\""
  enable_session_recording = false
  #storage_bucket_id                          = boundary_storage_bucket.session-storage.id
  host_source_ids = [
    boundary_host_set_static.set_db.id
  ]
  brokered_credential_source_ids = [
    boundary_credential_username_password.db.id
  ]
}
