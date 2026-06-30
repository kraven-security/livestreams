# elasticache.tf
# Managed Redis (ElastiCache) for MISP cache + background job queues. Transit
# encryption + an auth token are enabled.
#
# IMPORTANT TLS NOTE: with transit_encryption_enabled the app must connect over TLS
# using the *real* ElastiCache primary endpoint hostname (for SNI/cert validation).
# That's why we inject REDIS_HOST as the actual AWS endpoint via Secrets Manager,
# rather than aliasing it behind a Kubernetes ExternalName service. Confirm your
# misp-core build supports Redis TLS; if not, either run ElastiCache without transit
# encryption inside the private subnets, or front Redis with stunnel.

resource "random_password" "redis_auth" {
  length  = 32
  special = false # avoid REDIS_PASSWORD escaping pain ($ must be doubled in MISP)
}

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

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  apply_immediately = true
}
