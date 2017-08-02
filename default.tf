provider "aws" {
  region = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "chef_vault_testing" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name      = "Chef Vault Test VPC"
    X-Contact = "Thom May <tmay@chef.io>"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.chef_vault_testing.id}"
}

resource "aws_subnet" "primary" {
  vpc_id                  = "${aws_vpc.chef_vault_testing.id}"
  cidr_block              = "${var.vpc_cidr}"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.default"]

  tags {
    Name = "Public Subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.chef_vault_testing.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "primary" {
  subnet_id      = "${aws_subnet.primary.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "access" {
  name        = "access"
  description = "Network rules for default access"
  vpc_id      = "${aws_vpc.chef_vault_testing.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  egress {
    from_port   = 22
    to_port     = 22
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  egress {
    from_port   = 443
    to_port     = 443
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
  }

  egress {
    from_port   = 123
    to_port     = 123
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "udp"
  }

  tags {
    X-Contact = "Community Engineering <community-engineering@chef.io>"
  }
}

module "tf_chef_server" {
  source = "github.com/thommay/tf_chef_server"
  region = "${var.aws_region}"

  subnet_id = "${aws_subnet.primary.id}"

  vpc_security_group_ids = "${aws_security_group.access.id}"

  key_name                   = "${var.aws_key_pair}"
  private_ssh_key_path       = "${var.private_ssh_key_path}"
  ami                        = "${var.ami}"
  ssh_user                   = "ubuntu"
  chef_server_version        = "${var.chef-server-version}"
  chef_server_user           = "${var.chef-server-user}"
  chef_server_user_full_name = "${var.chef-server-user-full-name}"
  chef_server_user_email     = "${var.chef-server-user-email}"
  chef_server_user_password  = "${var.chef-server-user-password}"
  chef_server_org_name       = "${var.chef-server-org-name}"
  chef_server_org_full_name  = "${var.chef-server-org-full-name}"
}

data "template_file" "knife_rb" {
  template = "${file("${path.module}/templates/knife_rb.tpl")}"

  vars {
    chef-server-user         = "${var.chef-server-user}"
    organization             = "${var.chef-server-org-name}"
    chef-server-fqdn         = "${module.tf_chef_server.public_ip}"
    chef-server-organization = "${var.chef-server-org-name}"
  }
}

resource "null_resource" "build_knife_config" {
  # Make .chef/knife.rb file
  provisioner "local-exec" {
    command = "mkdir -p .chef && echo '${data.template_file.knife_rb.rendered}' > .chef/knife.rb"
  }

  # Download chef user pem
  provisioner "local-exec" {
    command = "scp -oStrictHostKeyChecking=no -i ${var.private_ssh_key_path} ubuntu@${module.tf_chef_server.public_ip}:${var.chef-server-user}.pem .chef/admin.pem"
  }

  # Fetch Chef Server Certificate
  provisioner "local-exec" {
    # changing to the parent directory so the trusted cert goes into ../.chef/trusted_certs
    command = "knife ssl fetch"
  }
}

resource "aws_instance" "client" {
  depends_on             = ["null_resource.build_knife_config"]
  ami                    = "${lookup(var.ami, var.aws_region)}"
  instance_type          = "t2.small"
  count                  = "${var.node-count}"
  subnet_id              = "${aws_subnet.primary.id}"
  vpc_security_group_ids = ["${aws_security_group.access.id}"]
  key_name               = "${var.aws_key_pair}"

  tags {
    Name      = "chef-server"
    X-Contact = "Thom May <tmay@chef.io>"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file("${var.private_ssh_key_path}")}"
    host        = "${self.public_ip}"
  }

  provisioner "chef" {
    server_url              = "https://${module.tf_chef_server.private_dns}/organizations/${var.chef-server-org-name}"
    node_name               = "vault_client_${count.index + 1}"
    fetch_chef_certificates = true
    run_list                = []
    recreate_client         = true
    user_name               = "${var.chef-server-user}"
    user_key                = "${file(".chef/admin.pem")}"
  }
}
