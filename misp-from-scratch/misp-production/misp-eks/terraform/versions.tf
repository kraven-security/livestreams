# versions.tf
# NOTE ON PINS: module/provider ecosystems move fast. The pins below were sane at
# authoring time. Before you run this live, do `terraform init -upgrade` on a scratch
# dir and bump to whatever is current, then re-test. Don't discover a breaking major
# version bump on air.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Recommended: remote state so the break-glass cluster and the live cluster don't
  # clobber each other. Use a separate `key` per workspace/cluster.
  # backend "s3" {
  #   bucket = "my-tf-state-bucket"
  #   key    = "misp-eks/terraform.tfstate"
  #   region = "eu-west-1"
  #   # dynamodb_table = "tf-locks"   # or use S3 native locking (use_lockfile) on newer providers
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "misp-eks"
      ManagedBy = "terraform"
      Owner     = var.owner
    }
  }
}

# The kubernetes/helm providers authenticate to the cluster created in this same
# config via an exec plugin (aws eks get-token). This is the standard single-apply
# pattern; it works because the providers resolve the token at apply time.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
