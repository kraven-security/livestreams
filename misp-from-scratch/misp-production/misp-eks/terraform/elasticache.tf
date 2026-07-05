# elasticache.tf
# Managed Redis (ElastiCache) for MISP cache + background job queues.
#
# TLS NOTE: transit encryption is OFF on purpose. ghcr.io/misp/misp-docker's
# /entrypoint.sh has no Redis TLS support at all (confirmed against CORE_TAG
# v2.5.30 — no TLS env var, no stunnel, nothing), so a transit-encrypted
# ElastiCache endpoint just gets `read error on connection ... Redis->auth()`
# from every MISP worker (AUTH sent in plaintext to a TLS-only listener). AWS
# also requires an auth_token to be dropped whenever transit encryption is off,
# so this relies on the security group (EKS node SG only) instead of a Redis
# password. Redis stays in private subnets, so that's an acceptable trade for a
# lab/livestream deployment. Revisit with a newer misp-core build or a stunnel
# sidecar before using this pattern for real production data.

resource "aws_security_group" "redis" {
  name_prefix = "${var.cluster_name}-redis-"
  description = "MISP ElastiCache access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_name}-redis"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.cluster_name}-redis"
  description          = "MISP cache and job queues"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type
  port           = 6379

  num_cache_clusters         = 1   # bump to >=2 + automatic_failover for HA
  automatic_failover_enabled = false

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  transit_encryption_enabled = false
  at_rest_encryption_enabled = true

  apply_immediately = true
}
