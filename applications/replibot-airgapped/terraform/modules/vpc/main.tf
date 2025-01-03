resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name           = "${var.name_prefix}-vpc"
    "network:cidr" = var.vpc_cidr_block
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}


resource "aws_subnet" "public" {
  for_each = var.public_cidr_block_map

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  availability_zone_id    = var.availability_zone_ids[each.key]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.name_prefix}-pub-subnet-${each.key}"
    "network:cidr"           = each.value
    "network:tier"           = "public"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_route_table" "public" {
  for_each = var.public_cidr_block_map

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name_prefix}-pub-route-${each.key}"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_route" "public" {
  for_each = var.public_cidr_block_map

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id

  depends_on = [
    aws_route_table.public
  ]
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id

  depends_on = [
    aws_route_table.public,
    aws_subnet.public
  ]
}

resource "aws_subnet" "private" {
  for_each = var.private_cidr_block_map

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value
  availability_zone_id    = var.availability_zone_ids[each.key]
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.name_prefix}-private-subnet-${each.key}"
    "network:cidr"           = each.value
    "network:tier"           = "private"
    "kubernetes.io/role/elb" = 1
  }
}

# resource "aws_eip" "private_nat" {
#   for_each = aws_subnet.private

#   tags = {
#     Name    = "${var.name_prefix}-nat-private-${each.key}"
#   }
# }

# resource "aws_nat_gateway" "private" {
#   for_each      = aws_subnet.private
#   allocation_id = aws_eip.private_nat[each.key].id
#   subnet_id     = aws_subnet.public[each.key].id

#   tags = {
#     Name    = "${var.name_prefix}-nat-private-${each.key}"
#   }
# }

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.vpc.id
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.private[each.key].id
  # }

  tags = {
    Name    = "${var.name_prefix}-private-route-table-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
