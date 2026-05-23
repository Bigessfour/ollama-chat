data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = merge(var.tags, {
    Module = "networking"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(aws_subnet.public)

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : length(aws_subnet.public)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(aws_subnet.private)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Custom NACL for private subnets (ALB health checks + NAT egress).
# Ollama (TCP 11434) is intentionally NOT allowed — it binds 127.0.0.1 on the Flask host only.
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-nacl"
  })
}

resource "aws_network_acl_rule" "private_inbound_http" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_subnet_cidrs[0]
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_inbound_http_az2" {
  count = length(var.public_subnet_cidrs) > 1 ? 1 : 0

  network_acl_id = aws_network_acl.private.id
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_subnet_cidrs[1]
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_inbound_flask" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 102
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_subnet_cidrs[0]
  from_port      = 5000
  to_port        = 5000
}

resource "aws_network_acl_rule" "private_inbound_flask_az2" {
  count = length(var.public_subnet_cidrs) > 1 ? 1 : 0

  network_acl_id = aws_network_acl.private.id
  rule_number    = 103
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_subnet_cidrs[1]
  from_port      = 5000
  to_port        = 5000
}

resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 1024
  to_port        = 65535
}

# Explicit deny: Ollama must stay on localhost only (defense in depth).
resource "aws_network_acl_rule" "private_deny_ollama" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 50
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  from_port      = 11434
  to_port        = 11434
}

resource "aws_network_acl_rule" "private_outbound_all" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.private.id
}
