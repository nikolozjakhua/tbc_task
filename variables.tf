variable "vpc_cidr_block" {
  default = "10.10.0.0/16"
}

variable "subnet" {
  default = "10.10.1.0/24"
}

variable "subnet_ip" {
  default = "10.10.1.10"
}

variable "region" {
  default = "eu-central-1"
}

variable "public_key_location" {
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key" {
  default = "~/.ssh/id_rsa"
}

variable "my_ip" {
  default = "213.157.206.250/32"
}

variable "s3_name" {
  default = "tbctasknj"
}