data "template_file" "worker" {
  template = (join("\n", tolist([
    file("${path.root}/templates/base.sh"),
    file("${path.root}/templates/worker.sh")
  ])))
  vars = {
    priv_key              = local.priv_key
    boundary_cluster_addr = local.boundary_cluster_addr
    worker_token          = local.worker_token
  }
}

data "template_cloudinit_config" "worker" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.worker.rendered
  }
}

# INSTANCES

resource "aws_instance" "bastionhost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.bastionhost.id]
  key_name                    = var.pub_key
  user_data                   = data.template_cloudinit_config.worker.rendered

  tags = {
    Name = "bastionhost-${var.name}"
  }
}

resource "aws_instance" "web_nodes" {
  count                       = var.web_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.web_subnet.*.id, count.index + 1)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.pub_key
  
  tags = {
    Name = format("web-%02d", count.index + 1)
  }
}


resource "boundary_host_catalog_static" "catalog" {
  name        = "webnodes-catalog"
  description = "My webnodes catalog"
  scope_id    = local.demo_project_id
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

# resource "boundary_credential_store_static" "example" {
#   name        = "boundary-credential-store"
#   description = "Internal Static Credential Store!"
#   scope_id    = local.demo_project_id
# }

resource "boundary_credential_ssh_private_key" "example" {
  name                = "webnodes"
  description         = "SSH Private Key for webnodes"
  #credential_store_id = boundary_credential_store_static.example.id
  credential_store_id = local.cred_store_static
  username            = "ubuntu"
  private_key         = local.priv_key
  #private_key_passphrase = "optional-passphrase" # change to the passphrase of the Private Key if required
}

resource "boundary_target" "ssh_hosts" {
  name                     = "ssh-static-injection-webnodes"
  description              = "ssh webnode targets"
  type                     = "ssh"
  default_port             = "22"
  scope_id                 = local.demo_project_id
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


## next use case dynamic ssh via vault


resource "aws_instance" "db_nodes" {
  count                       = var.db_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.web_subnet.*.id, count.index + 1)
  associate_public_ip_address = "false"
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = var.pub_key
  
  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /etc/ssh/
              rm -rf /etc/ssh/ca-key.pub
              echo "${local.vault_ca_pub_key}" | sed '$d' > /etc/ssh/ca-key.pub
              #chown 1000:1000 /etc/ssh/ca-key.pub
              chmod 644 /etc/ssh/ca-key.pub
              echo "TrustedUserCAKeys /etc/ssh/ca-key.pub" >> /etc/ssh/sshd_config
              sudo systemctl restart sshd.service
              apt-get update
              apt-get install -y mysql-server
              sudo tee /etc/mysql/myql.conf.d/mysqld.cnf > /dev/null <<EOT
                [mysqld]
                user            = mysql
                bind-address            = 0.0.0.0
                mysqlx-bind-address     = 127.0.0.1
                key_buffer_size         = 16M
                myisam-recover-options  = BACKUP
                log_error = /var/log/mysql/error.log
                max_binlog_size   = 100M
              EOT
              echo "CREATE USER 'boundary'@'%' IDENTIFIED WITH mysql_native_password BY 'boundary1234!';" > /home/ubuntu/demo.sql
              echo "GRANT ALL PRIVILEGES ON *.* TO 'boundary'@'%' WITH GRANT OPTION;" >> /home/ubuntu/demo.sql
              sudo mysql < /home/ubuntu/demo.sql
              EOF
  
  tags = {
    Name = format("db-%02d", count.index + 1)
  }
}

resource "boundary_host_catalog_static" "catalog_db" {
  name        = "db-catalog"
  description = "My dbnodes catalog"
  scope_id    = local.demo_project_id
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


# //Credential store for Vault
# resource "boundary_credential_store_vault" "vault_cred_store_dyn" {
#   name        = "vault-credential-store"
#   description = "Vault Dynamic Credential Store"
#   address     = local.vault_cluster_addr
#   token       = local.vault_boundary_token
#   namespace   = local.vault_namespace
#   scope_id    = local.demo_project_id
# }


resource "boundary_credential_library_vault_ssh_certificate" "vault" {
  name                = "certificates-library"
  description         = "Vault CA to grant access to dbnodes"
  #credential_store_id = boundary_credential_store_vault.vault_cred_store_dyn.id
  credential_store_id = local.cred_store_vault
  path                = "ssh-client-signer/sign/boundary-client"
  username            = "ubuntu"
  key_type            = "ecdsa"
  key_bits            = 521
  extensions          = {
    permit-pty = ""
  }
}


resource "boundary_target" "ssh_hosts_db" {
  name                     = "ssh-dynamic-injection-dbnodes"
  description              = "ssh dbnode targets"
  type                     = "ssh"
  default_port             = "22"
  scope_id                 = local.demo_project_id
  ingress_worker_filter    = "\"worker1\" in \"/tags/type\""
  enable_session_recording = false
  #storage_bucket_id                          = boundary_storage_bucket.session-storage.id
  host_source_ids = [
    boundary_host_set_static.set_db.id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_library_vault_ssh_certificate.vault.id
  ]
}

