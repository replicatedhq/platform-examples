variable "name_prefix" {
  description = "Name prefix for all resources created by this module"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The VPC CIDR block"
  type        = string
}

variable "nat_instance_image_id" {
  description = "AMI of the NAT instance. Default to the latest Amazon Linux 2"
  type        = string
  default     = ""
}

variable "public_cidr_block_map" {
  description = "A map where the key is AZ short name and value is public subnet CIDR"
  type        = map(string)
}

variable "private_cidr_block_map" {
  description = "A map where the key is AZ short name and value is private subnet CIDR"
  type        = map(string)
}

variable "availability_zone_ids" {
  description = "Map AZ short name to its actual availability zone id"
  type        = map(string)
  default = {
    a = "apse2-az1",
    b = "apse2-az2",
    c = "apse2-az3"
  }
}
