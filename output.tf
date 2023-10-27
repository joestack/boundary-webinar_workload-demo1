output "Bastionhost_public_IP" {
  value = "ssh ${var.ssh_user}@${aws_instance.bastionhost.public_ip}"
}

output "inventory" {
  value = data.template_file.ansible_skeleton.rendered
}

output "ansible_hosts" {
  value = data.template_file.ansible_web_hosts.*.rendered
}

output "web_node_ips" {
  value = aws_instance.web_nodes.*.private_ip
}

output "vpc_id" {
  value = aws_vpc.hashicorp_vpc.id
}

output "ca_public_key" {
  value = tls_private_key.signing-key.public_key_openssh
}

output "vault_boundary_token" {
  value = vault_token.boundary-credentials-store-token.client_token
  sensitive = true
}

output "vault_admin_token" {
  value = local.vault_admin_token
}

output "activation_token" {
  value = boundary_worker.controller_led.controller_generated_activation_token
}

output "boundary_cluster" {
  value = local.boundary_cluster_addr
}

