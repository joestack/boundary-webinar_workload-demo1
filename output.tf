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