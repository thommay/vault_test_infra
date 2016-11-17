variable "aws_region" {
  description = "AWS Region for all instances in network"
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "Network CIDR for vpc"
  default     = "10.0.0.0/16"
}

variable "primary_cidr" {
  description = "Network CIDR for public network"
  default     = "10.0.0.0/24"
}

variable "secondary_cidr" {
  description = "Network CIDR for secondary network"
  default     = "10.0.1.0/24"
}

variable "ami" {
  description = "Base AMI for all nodes"

  default = {
    us-west-2 = "ami-746aba14"
  }
}

variable "aws_key_pair" {
  description = "Required aws key pair"
  default     = "thom"
}

variable "private_ssh_key_path" {
  description = "SSH Key"
  default     = "/Users/thom/.ssh/ec2_us_west_2"
}

variable "chef-server-version" {
  description = "Chef server version"
  default = "12.9.1"
}

variable "chef-server-user" {
  description = "Chef server user"
}

variable "chef-server-user-full-name" {
  description = "Chef server user name"
}

variable "chef-server-user-email" {
  description = "Chef server user email"
}

variable "chef-server-user-password" {
  description = "Chef server user password"
}

variable "chef-server-org-name" {
  description = "Chef server org name"
}

variable "chef-server-org-full-name" {
  description = "Chef server org full name"
}

variable "node-count" {
  default = 10
}
