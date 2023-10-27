data "terraform_remote_state" "hcp" {
  backend = "remote"

  config = {
    organization = var.tfc_state_org
    workspaces = {
      name = var.rs_platform_hcp
    }
  }
}

locals {
  priv_key              = base64decode(var.pri_key)
  vault_cluster_addr    = data.terraform_remote_state.hcp.outputs.vault_cluster_public_url
  vault_namespace       = data.terraform_remote_state.hcp.outputs.vault_namespace
  vault_admin_token     = data.terraform_remote_state.hcp.outputs.vault_admin_token
  boundary_cluster_addr = data.terraform_remote_state.hcp.outputs.boundary_cluster_url
  worker_token          = boundary_worker.controller_led.controller_generated_activation_token
  vault_ca_pub_key      = tls_private_key.signing-key.public_key_openssh
  
  #demo_project_id       = boundary_scope.project.id
  
  # boundary_cluster_addr = data.terraform_remote_state.platform_services.outputs.boundary_cluster
  # worker_token          = data.terraform_remote_state.platform_services.outputs.activation_token
  # demo_org_id           = data.terraform_remote_state.platform_services.outputs.demo_org_id
  # demo_project_id       = data.terraform_remote_state.platform_services.outputs.demo_project_id
  # cred_store_static     = data.terraform_remote_state.platform_services.outputs.cred_store_static
  # cred_store_vault      = data.terraform_remote_state.platform_services.outputs.cred_store_vault
  # vault_ca_pub_key      = data.terraform_remote_state.platform_services.outputs.ca_public_key
  # vault_boundary_token  = data.terraform_remote_state.platform_services.outputs.vault_boundary_token
}



provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_eip" "nat_gateway" {
  #vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.dmz_subnet.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}


# Network & Routing
# VPC 

resource "aws_vpc" "hashicorp_vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.name}-vpc"
  }
}

# Internet Gateways and route table

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hashicorp_vpc.id
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.hashicorp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-igw"
  }
}

# nat route table

resource "aws_route_table" "rtb-nat" {
  vpc_id = aws_vpc.hashicorp_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.name}-nat_instance"
  }
}

# public subnet to IGW

resource "aws_route_table_association" "dmz-subnet" {
  subnet_id      = aws_subnet.dmz_subnet.*.id[0]
  route_table_id = aws_route_table.rtb.id
}

# limit the amout of public web subnets to the amount of AZ
resource "aws_route_table_association" "pub_web-subnet" {
  count          = var.web_subnet_count
  subnet_id      = element(aws_subnet.pub_web_subnet.*.id, count.index)
  route_table_id = aws_route_table.rtb.id
}

# private subnet to NAT

resource "aws_route_table_association" "rtb-web" {
  count          = var.web_subnet_count
  subnet_id      = element(aws_subnet.web_subnet.*.id, count.index)
  route_table_id = aws_route_table.rtb-nat.id
}

# subnet public

resource "aws_subnet" "dmz_subnet" {
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  cidr_block              = cidrsubnet(var.network_address_space, 8, 1)
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "dmz-subnet"
  }
}

resource "aws_subnet" "pub_web_subnet" {
  count                   = var.web_subnet_count
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index + 10)
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "web-pub-subnet"
  }
}

# subnet private

resource "aws_subnet" "web_subnet" {
  count                   = var.web_subnet_count
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index + 20)
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  map_public_ip_on_launch = "false"

  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "web-prv-subnet"
  }
}

## Access and Security Groups

resource "aws_security_group" "bastionhost" {
  name        = "${var.name}-bastionhost-sg"
  description = "Bastionhosts"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "jh-ssh" {
  security_group_id = aws_security_group.bastionhost.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jh-boundary" {
  security_group_id = aws_security_group.bastionhost.id
  type              = "ingress"
  from_port         = 9202
  to_port           = 9202
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jh-egress" {
  security_group_id = aws_security_group.bastionhost.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "private webserver"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "web-http" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-https" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-ssh" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web-mysql" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "web-egress" {
  security_group_id = aws_security_group.web.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group" "nat" {
  name        = "${var.name}-nat-sg"
  description = "nat instance"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "nat-http" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nat-htts" {
  security_group_id = aws_security_group.nat.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nat-egress" {
  security_group_id = aws_security_group.nat.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

