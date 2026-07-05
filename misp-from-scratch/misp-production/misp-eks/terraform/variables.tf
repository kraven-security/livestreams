# variables.tf

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2" # London
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

variable "node_min" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 4
}

variable "node_desired" {
  type    = number
  default = 2
}

# ---- Database (RDS for MariaDB) ----
variable "db_engine_version" {
  description = "RDS MariaDB version. MariaDB is the recommended MISP engine."
  type        = string
  default     = "11.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium" # bump for production load
}

variable "db_allocated_storage" {
  type    = number
  default = 50
}

variable "db_multi_az" {
  type    = bool
  default = false # set true for production HA
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
  type    = string
  default = "cache.t3.medium"
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
