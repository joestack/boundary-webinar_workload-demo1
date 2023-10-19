## dynamically generate an Ansible Inventory-File using nested Terraform Templates
## -one template contains the entire skeleton of the Inventory-File
## -the other template generates the amount of nodes within a [class]  

##
## here we create the list of available Nodes for the [WEB] class
## to be used as input for the skeleton template
##
data "template_file" "ansible_web_hosts" {
  count      = var.web_node_count
  template   = file("${path.root}/templates/ansible_hosts.tpl")
  depends_on = [aws_instance.web_nodes]

  vars = {
    node_name    = aws_instance.web_nodes.*.tags[count.index]["Name"]
    ansible_user = var.ssh_user
    ip           = element(aws_instance.web_nodes.*.private_ip, count.index)
  }
}

##
## here we create the list of available Nodes for the [DB] class
## to be used as input for the skeleton template
##
data "template_file" "ansible_db_hosts" {
  count      = var.db_node_count
  template   = file("${path.root}/templates/ansible_hosts.tpl")
  depends_on = [aws_instance.db_nodes]

  vars = {
    node_name    = aws_instance.db_nodes.*.tags[count.index]["Name"]
    ansible_user = var.ssh_user
    ip        = "ansible_host=${element(aws_instance.db_nodes.*.private_ip, count.index)}"
  }
}



##
## here we assign the nodes of each [class] to the Inventory-File skeleton template file 
## 
data "template_file" "ansible_skeleton" {
  template = file("${path.root}/templates/ansible_skeleton.tpl")

  vars = {
    web_hosts_def = join("", data.template_file.ansible_web_hosts.*.rendered)
    db_hosts_def = join("", data.template_file.ansible_db_hosts.*.rendered) 
  }
}


##
## here we write the rendered Inventory-File to a local file
## on the Terraform exec environment 
##
resource "local_file" "ansible_inventory" {
  depends_on = [data.template_file.ansible_skeleton]

  content  = data.template_file.ansible_skeleton.rendered
  filename = "${path.root}/inventory"
}

##
## here we copy the local file to the bastionhost
## using a "null_resource" to be able to trigger a file provisioner
##
resource "null_resource" "provisioner" {
  depends_on = [local_file.ansible_inventory]

  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.root}/inventory"
    destination = "/home/ubuntu/inventory"

    connection {
      type        = "ssh"
      host        = aws_instance.bastionhost.public_ip
      user        = var.ssh_user
      private_key = local.priv_key
      #insecure    = true
    }
  }
}


