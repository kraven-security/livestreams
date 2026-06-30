# vpc.tf
# Standard 3-AZ VPC with public + private subnets. Subnet tags let the AWS Load
# Balancer Controller auto-discover where to place internet-facing ALBs (public)
# vs internal ones (private).

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Carve /20s out of the VPC CIDR for private subnets and /24s for public.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 48)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true # cheaper for a lab; use one-per-AZ for production resilience
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ALB controller discovery tags
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
