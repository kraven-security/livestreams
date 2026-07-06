# locals.tf
# Derived values kept in one place so the rest of the config stays declarative.

locals {
  # RDS parameter-group family + major version, derived from db_engine_version so a
  # version bump (e.g. "11.4" -> "11.8") carries through automatically instead of
  # silently mismatching a hardcoded "mariadb11.4". Takes the major.minor of the
  # engine version: "11.4" -> "11.4", "11.4.3" -> "11.4".
  db_major  = join(".", slice(split(".", var.db_engine_version), 0, 2))
  db_family = "mariadb${local.db_major}"

  # Production-aware effective sizing. Each explicit variable (when set) wins via
  # coalesce; otherwise var.production picks the lab or prod default. This is what
  # makes lab<->prod a single switch instead of a dozen manual edits.
  effective_node_min    = coalesce(var.node_min, var.production ? 2 : 1)
  effective_node_max    = coalesce(var.node_max, var.production ? 4 : 3)
  effective_db_class    = coalesce(var.db_instance_class, var.production ? "db.t3.medium" : "db.t3.small")
  effective_db_storage  = coalesce(var.db_allocated_storage, var.production ? 50 : 20)
  effective_db_multi_az = coalesce(var.db_multi_az, var.production)
  effective_redis_class = coalesce(var.redis_node_type, var.production ? "cache.t3.medium" : "cache.t3.small")

  # HA/durability/safety levers, all driven directly by the toggle.
  effective_redis_nodes = var.production ? 2 : 1
  secret_recovery_days  = var.production ? 7 : 0
}
