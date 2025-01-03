output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  value = var.vpc_cidr_block
}

output "public_subnets" {
  value = aws_subnet.public
}

output "public_route_tables" {
  value = aws_route_table.public
}

output "private_subnets" {
  value = aws_subnet.private
}

output "private_route_tables" {
  value = aws_route_table.private
}
