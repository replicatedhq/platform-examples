variable "env" {
  description = "Infrastructure environment"
  type        = string
}

variable "account_owner" {
  description = "Account owner"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The VPC CIDR block"
  type        = string
}

variable "public_cidr_block_map" {
  description = "A map where the key is AZ short name and value is public subnet CIDR"
  type        = map(string)
}

variable "private_cidr_block_map" {
  description = "A map where the key is AZ short name and value is private subnet CIDR"
  type        = map(string)
}

variable "key_name" {
  description = "The name of the EC2 key pair to allow SSH access to the instance"
  type        = string
}

variable "airgap_download_script" {
  description = "value of the airgap download script"
  type        = string
  
}
