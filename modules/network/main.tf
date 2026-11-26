
locals {
  all_subnet_cidrs = concat(
    var.public_subnet_cidrs,
    var.private_app_subnet_cidrs,
    var.private_db_subnet_cidrs,
  )
  vpc_prefix = join(".", slice(split(".", split("/", var.vpc_cidr)[0]), 0, 2))
}

# ==========================================
# VPC
# ==========================================

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:VPC Flow Logs need a destination and retention policy with ongoing ingestion and storage costs, deferred from this demo.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })

  lifecycle {
    precondition {
      condition     = endswith(var.vpc_cidr, "/16")
      error_message = "The standard network layout requires a /16 VPC CIDR."
    }

    precondition {
      condition = alltrue([
        for cidr in local.all_subnet_cidrs :
        startswith(cidr, "${local.vpc_prefix}.") && endswith(cidr, "/24")
      ])
      error_message = "Every standard subnet must be a /24 contained in the configured VPC /16."
    }

    precondition {
      condition     = length(distinct(local.all_subnet_cidrs)) == length(local.all_subnet_cidrs)
      error_message = "Public, application, and database subnet CIDRs must not overlap."
    }
    precondition {
      condition = alltrue([
        for cidr in local.all_subnet_cidrs :
        cidrsubnet(cidr, 0, 0) == cidr && endswith(cidr, "/24")
      ])
      error_message = "Every subnet must be a canonical /24 CIDR."
    }
  }
}

# ==========================================
# DEFAULT SECURITY GROUP
# ==========================================

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-default-sg-restricted"
  })
}


# ==========================================
# PUBLIC SUBNETS
# ==========================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# ==========================================
# PRIVATE APPLICATION SUBNETS
# ==========================================

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-app-${count.index + 1}"
    Tier = "private-app"
  })
}

# ==========================================
# PRIVATE DATABASE SUBNETS
# ==========================================

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-db-${count.index + 1}"
    Tier = "private-db"
  })
}

# ==========================================
# INTERNET GATEWAY
# ==========================================

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# ==========================================
# ROUTE TABLES
# ==========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route_table" "private_app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-app-${count.index + 1}-rt"
    Tier = "private-app"
  })
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-db-rt"
    Tier = "private-db"
  })
}

# ==========================================
# ROUTE TABLE ASSOCIATIONS
# ==========================================

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table_association" "private_db" {
  count = length(aws_subnet.private_db)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

# ==========================================
# PUBLIC INTERNET ROUTE
# ==========================================

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# ==========================================
# NAT ELASTIC IPs
# ==========================================

resource "aws_eip" "nat" {
  count  = var.nat_gateway_count
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# ==========================================
# NAT GATEWAYS
# ==========================================

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-gateway-${count.index + 1}"
  })

  depends_on = [
    aws_internet_gateway.this,
    aws_route.public_internet
  ]
}

# ==========================================
# PRIVATE APPLICATION INTERNET ROUTES
# ==========================================

resource "aws_route" "private_app_internet" {
  count = length(var.availability_zones)

  route_table_id = aws_route_table.private_app[count.index].id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.this[
    var.nat_gateway_count == 1 ? 0 : count.index
  ].id
}
