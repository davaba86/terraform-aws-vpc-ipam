# ##############################################################################
# Main IPAM Resource
# ##############################################################################

resource "aws_vpc_ipam" "main" {
  description = "Global IPAM"

  dynamic "operating_regions" {
    for_each = local.deduplicated_region_list

    content {
      region_name = operating_regions.value
    }
  }

  tags = {
    Environment = terraform.workspace
    Name        = "root"
  }
}

# ##############################################################################
# Top Level Pool
# ##############################################################################

resource "aws_vpc_ipam_pool" "top_level" {
  description    = "All envs regardless of account and region."
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id

  tags = {
    Environment = terraform.workspace
    Name        = "root"
  }
}

resource "aws_vpc_ipam_pool_cidr" "top_level" {
  ipam_pool_id = aws_vpc_ipam_pool.top_level.id
  cidr         = var.top_level_pool_cidr
}

# ##############################################################################
# Environment Level Pool
# ##############################################################################

resource "aws_vpc_ipam_pool" "envs" {
  for_each = {
    for key, value in var.envs : key => value
  }

  description         = "Env regardless of account and region."
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.top_level.id

  tags = {
    Environment = terraform.workspace
    Name        = each.value.environment
  }
}

resource "aws_vpc_ipam_pool_cidr" "envs" {
  for_each = {
    for key, value in var.envs : key => value
  }

  ipam_pool_id = aws_vpc_ipam_pool.envs[each.key].id
  cidr         = each.value.cidr-main
}


# ##############################################################################
# Region Level Pool
# ##############################################################################

resource "aws_vpc_ipam_pool" "ireland" {
  for_each = {
    for key, value in aws_vpc_ipam_pool.envs : key => value
  }

  description         = "Env tied to eu-west-1."
  address_family      = "ipv4"
  locale              = "eu-west-1"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  source_ipam_pool_id = each.value.id

  tags = {
    Environment = terraform.workspace
    Name        = "${each.value.tags["Name"]}-ireland"
  }
}

resource "aws_vpc_ipam_pool_cidr" "ireland" {
  for_each = {
    for index, data in aws_vpc_ipam_pool.ireland : index => data
  }

  ipam_pool_id = each.value.id
  cidr         = "10.${each.key}.0.0/17"
}

resource "aws_vpc_ipam_pool" "frankfurt" {
  for_each = {
    for key, value in aws_vpc_ipam_pool.envs : key => value
  }

  description         = "Env tied to eu-central-1."
  address_family      = "ipv4"
  locale              = "eu-central-1"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  source_ipam_pool_id = each.value.id

  tags = {
    Environment = terraform.workspace
    Name        = "${each.value.tags["Name"]}-frankfurt"
  }
}

resource "aws_vpc_ipam_pool_cidr" "frankfurt" {
  for_each = {
    for index, data in aws_vpc_ipam_pool.frankfurt : index => data
  }

  ipam_pool_id = each.value.id
  cidr         = "10.${each.key}.128.0/17"
}

# ##############################################################################
# Resource Access Manager (RAM) - test
# ##############################################################################

resource "aws_ram_resource_share" "ipam_test" {
  name                      = "ipam_share_test"
  allow_external_principals = false
}

resource "aws_ram_principal_association" "ipam_test" {
  principal          = "069942508843"
  resource_share_arn = aws_ram_resource_share.ipam_test.arn
}

resource "aws_ram_resource_association" "ipam_test_ireland" {
  resource_arn       = data.aws_vpc_ipam_pool.test_ireland.arn
  resource_share_arn = aws_ram_resource_share.ipam_test.arn
}

data "aws_vpc_ipam_pool" "test_ireland" {
  filter {
    name   = "tag:Name"
    values = ["test-ireland"]
  }

  depends_on = [
    aws_vpc_ipam_pool.ireland
  ]
}

resource "aws_ram_resource_association" "ipam_test_frankfurt" {
  resource_arn       = data.aws_vpc_ipam_pool.test_frankfurt.arn
  resource_share_arn = aws_ram_resource_share.ipam_test.arn
}

data "aws_vpc_ipam_pool" "test_frankfurt" {
  filter {
    name   = "tag:Name"
    values = ["test-frankfurt"]
  }

  depends_on = [
    aws_vpc_ipam_pool.frankfurt
  ]
}

# ##############################################################################
# Resource Access Manager (RAM) - prod
# ##############################################################################

resource "aws_ram_resource_share" "ipam_prod" {
  name                      = "ipam_share_prod"
  allow_external_principals = false
}

resource "aws_ram_principal_association" "ipam_prod" {
  principal          = "744092344546"
  resource_share_arn = aws_ram_resource_share.ipam_prod.arn
}

resource "aws_ram_resource_association" "ipam_prod_ireland" {
  resource_arn       = data.aws_vpc_ipam_pool.prod_ireland.arn
  resource_share_arn = aws_ram_resource_share.ipam_prod.arn
}

data "aws_vpc_ipam_pool" "prod_ireland" {
  filter {
    name   = "tag:Name"
    values = ["prod-ireland"]
  }

  depends_on = [
    aws_vpc_ipam_pool.ireland
  ]
}

resource "aws_ram_resource_association" "ipam_prod_frankfurt" {
  resource_arn       = data.aws_vpc_ipam_pool.prod_frankfurt.arn
  resource_share_arn = aws_ram_resource_share.ipam_prod.arn
}

data "aws_vpc_ipam_pool" "prod_frankfurt" {
  filter {
    name   = "tag:Name"
    values = ["prod-frankfurt"]
  }

  depends_on = [
    aws_vpc_ipam_pool.frankfurt
  ]
}
