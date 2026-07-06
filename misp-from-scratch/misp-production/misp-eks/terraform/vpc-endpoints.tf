# vpc-endpoints.tf
# S3 Gateway Endpoint — free (no hourly charge, no per-GB charge), so there's no
# reason not to have it. Without it, two real traffic flows pay the NAT gateway's
# ~$0.045/GB data-processing charge for no benefit:
#   - MISP attachment storage (storage-iam.tf's aws_s3_bucket.attachments)
#   - ECR image layer pulls for misp-core/misp-modules/addon images (backed by S3
#     under the hood, even though fetched via the ECR API)
#
# Deliberately NOT adding ECR interface endpoints (ecr.api/ecr.dkr, ~$0.01/hr each
# + their own per-GB charge): this stack is destroyed between demo sessions, so
# nodes are only created once per session — image pulls are infrequent enough
# that interface endpoints wouldn't pay for themselves in NAT savings.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}
