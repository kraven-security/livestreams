# addons.tf
# AWS Load Balancer Controller (provisions the ALB from the Ingress) and the
# External Secrets Operator (syncs AWS Secrets Manager -> Kubernetes Secrets).
# The eks-blueprints-addons module wires up IRSA + the Helm releases for both.

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.20"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  enable_external_secrets             = true

  # Optional: EFS CSI driver if you choose the RWX-PVC path for attachments
  # instead of S3. Leave off if you use S3 (recommended).
  # enable_aws_efs_csi_driver = true

  tags = {
    Project = "misp-eks"
  }
}
