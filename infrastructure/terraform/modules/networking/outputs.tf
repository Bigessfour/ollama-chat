output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  value = var.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  value = var.private_subnet_cidrs
}

output "availability_zones" {
  value = local.azs
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}
