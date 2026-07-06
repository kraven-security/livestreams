# secrets.tf
# Generate MISP crypto material and admin secrets, then store everything (including
# the AWS endpoints) in two AWS Secrets Manager secrets whose JSON keys map 1:1 to
# the Kubernetes Secrets that External Secrets will create:
#   - misp/mysql-credentials  -> k8s secret "mysql-credentials"
#   - misp/instance-secrets   -> k8s secret "instance-secrets"
#
# Pinning ENCRYPTION_KEY, SECURITY_SALT, MISP UUID and ADMIN_ORG_UUID to static
# values is what lets you scale misp-core to >1 replica without CSRF errors.

resource "random_password" "admin" {
  length  = 24
  special = true
}

resource "random_password" "encryption_key" {
  length  = 48
  special = false
}

resource "random_password" "security_salt" {
  length  = 48
  special = false
}

resource "random_password" "gpg_passphrase" {
  length  = 32
  special = false
}

resource "random_uuid" "misp_uuid" {}
resource "random_uuid" "admin_org_uuid" {}

# ---- mysql-credentials ----
resource "aws_secretsmanager_secret" "mysql" {
  name                    = "misp/mysql-credentials"
  recovery_window_in_days = local.secret_recovery_days # 0 (immediate delete) in the lab, 7 in prod
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    MYSQL_HOST          = module.rds.db_instance_address
    MYSQL_PORT          = "3306"
    MYSQL_USER          = var.db_username
    MYSQL_PASSWORD      = random_password.db.result
    MYSQL_DATABASE      = var.db_name
    MYSQL_ROOT_PASSWORD = random_password.db_root.result
  })
}

# ---- instance-secrets ----
resource "aws_secretsmanager_secret" "instance" {
  name                    = "misp/instance-secrets"
  recovery_window_in_days = local.secret_recovery_days
}

resource "aws_secretsmanager_secret_version" "instance" {
  secret_id = aws_secretsmanager_secret.instance.id
  secret_string = jsonencode({
    # Admin / identity
    ADMIN_EMAIL    = var.admin_email != "" ? var.admin_email : "admin@${var.misp_hostname}"
    ADMIN_PASSWORD = random_password.admin.result
    ADMIN_ORG      = var.admin_org
    ADMIN_ORG_UUID = random_uuid.admin_org_uuid.result
    MISP_UUID      = random_uuid.misp_uuid.result

    # Crypto material — pin these identically across all misp-core replicas
    ENCRYPTION_KEY = random_password.encryption_key.result
    SECURITY_SALT  = random_password.security_salt.result
    GPG_PASSPHRASE = random_password.gpg_passphrase.result

    # Public URL + proxy awareness (behind the ALB)
    BASE_URL = "https://${var.misp_hostname}"

    # Redis (real endpoint; no transit encryption/auth token — see elasticache.tf)
    REDIS_HOST     = aws_elasticache_replication_group.this.primary_endpoint_address
    REDIS_PORT     = "6379"
    REDIS_PASSWORD = ""

    # S3 attachments
    S3_ENABLE     = "true"
    S3_BUCKET     = aws_s3_bucket.attachments.bucket
    S3_ENDPOINT   = "https://s3.${var.region}.amazonaws.com"
    S3_ACCESS_KEY = aws_iam_access_key.misp_s3.id
    S3_SECRET_KEY = aws_iam_access_key.misp_s3.secret
  })
}
