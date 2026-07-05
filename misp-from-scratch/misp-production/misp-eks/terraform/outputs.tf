# outputs.tf

output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  value = module.rds.db_instance_address
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "attachments_bucket" {
  value = aws_s3_bucket.attachments.bucket
}

output "acm_certificate_arn" {
  value = var.acm_certificate_arn
}

output "misp_hostname" {
  value = var.misp_hostname
}

# After apply, create the Route 53 (or other DNS) record pointing misp_hostname at
# the ALB hostname. The ALB is created by the Ingress, so its hostname is known only
# after you apply the k8s manifests:
#   kubectl -n misp get ingress misp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
output "dns_hint" {
  value = "After applying k8s/, point ${var.misp_hostname} (CNAME/ALIAS) at the ALB hostname from: kubectl -n ${var.namespace} get ingress misp"
}
