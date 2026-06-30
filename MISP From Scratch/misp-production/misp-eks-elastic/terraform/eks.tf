# eks.tf
# EKS control plane + a managed node group in private subnets. IRSA enabled so
# pods (External Secrets, ALB controller, MISP S3 access) get scoped IAM roles
# instead of node-wide credentials.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Public endpoint so you can kubectl from your stream box. For production, set
  # cluster_endpoint_public_access_cidrs to your egress IP, or go private + bastion.
  cluster_endpoint_public_access = true

  enable_irsa = true

  # Gives the identity running `terraform apply` admin on the cluster via an access
  # entry, so kubectl works immediately after apply.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min
      max_size       = var.node_max
      desired_size   = var.node_desired
      # Pre-pull the large misp-core image into the AMI cache off-air if you can;
      # a cold pull on a fresh node is a classic on-air stall.
    }
  }
}
