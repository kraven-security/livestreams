# variables.tf

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "owner" {
  description = "Tag applied to all resources"
  type        = string
  default     = "kraven-security"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "misp-prod"
}

variable "cluster_version" {
  description = "EKS Kubernetes version. Pick a version AWS currently supports."
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "VPC CIDR. MISP nginx will trust X-Forwarded-For from this range."
  type        = string
  default     = "10.42.0.0/16"
}

# ---- Environment mode ----
# The single lab<->prod switch. false (default) = cheap, disposable livestream lab
# (single NAT, single-AZ RDS, one Redis node, small burstable classes, resources
# deleted cleanly on `make down`). true = production-shaped (HA + durability +
# deletion protection). It only sets DEFAULTS — every individual sizing/HA variable
# below still overrides it when set explicitly, so you can mix (e.g. production=true
# but a smaller db_instance_class).
variable "production" {
  description = "Master toggle: false = cost-minimized lab, true = production-shaped (HA + durable)."
  type        = bool
  default     = false
}

variable "az_count" {
  description = "Number of AZs to spread across"
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "EKS managed node group instance types"
  type        = list(string)
  default     = ["m5.large"]
}

# Sizing vars below default to null and fall back to production-aware values in
# locals.tf (lab vs prod). Set any of them explicitly to override the toggle.
variable "node_min" {
  description = "Node group min size. null => 2 if production else 1."
  type        = number
  default     = null
}

variable "node_max" {
  description = "Node group max size. null => 4 if production else 3."
  type        = number
  default     = null
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Lock this to your egress IP for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---- Database (RDS for MariaDB) ----
variable "db_engine_version" {
  description = "RDS MariaDB version. MariaDB is the recommended MISP engine."
  type        = string
  default     = "11.4"
}

variable "db_instance_class" {
  description = "RDS instance class. null => db.t3.medium if production else db.t3.small."
  type        = string
  default     = null
}

variable "db_allocated_storage" {
  description = "RDS storage (GB). null => 50 if production else 20. Storage can only grow later, not shrink."
  type        = number
  default     = null
}

variable "db_multi_az" {
  description = "RDS Multi-AZ. null => follows the production toggle."
  type        = bool
  default     = null
}

variable "db_name" {
  type    = string
  default = "misp"
}

variable "db_username" {
  type    = string
  default = "misp"
}

# ---- Cache (ElastiCache for Redis) ----
variable "redis_node_type" {
  description = "ElastiCache node type. null => cache.t3.medium if production else cache.t3.small."
  type        = string
  default     = null
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

# ---- MISP / DNS ----
variable "misp_hostname" {
  description = "FQDN MISP will be served on, e.g. misp.lab.kravensecurity.com"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of a pre-issued, DNS-validated ACM cert for misp_hostname. Issue this OFF-AIR; validation is slow."
  type        = string
}

variable "admin_org" {
  description = "Name of the initial MISP admin organisation. Change this to your own org."
  type        = string
  default     = "Kraven Security"
}

variable "admin_email" {
  description = "Initial MISP admin login. Empty (default) => admin@<misp_hostname>."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for MISP"
  type        = string
  default     = "misp"
}

variable "misp_service_account" {
  description = "ServiceAccount name the MISP pod runs as (used for S3 IRSA)"
  type        = string
  default     = "misp"
}
