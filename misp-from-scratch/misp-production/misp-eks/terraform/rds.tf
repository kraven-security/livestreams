# rds.tf
# Managed MariaDB on RDS. MariaDB is the safer MISP target than MySQL 8 (the latter
# has a known "table does not comply with the requirements by an external plugin"
# class of issues on login). Password is alphanumeric-only on purpose — MISP's
# config handling dislikes special chars in the DB password.

resource "random_password" "db" {
  length  = 32
  special = false # alphanumeric only for MISP DB compatibility
}

resource "random_password" "db_root" {
  length  = 32
  special = false
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "MISP RDS access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL/MariaDB from EKS nodes"
    from_port       = 3306
    to_port         = 3306
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

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.10"

  identifier = "${var.cluster_name}-mariadb"

  engine               = "mariadb"
  engine_version       = var.db_engine_version
  family               = local.db_family # derived from db_engine_version (locals.tf)
  major_engine_version = local.db_major
  instance_class       = local.effective_db_class
  allocated_storage    = local.effective_db_storage
  storage_type         = "gp3"
  storage_encrypted    = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  # We manage the password ourselves (random_password) so the exact same value lands
  # in Secrets Manager for MISP. Disable RDS-managed master password.
  manage_master_user_password = false

  multi_az               = local.effective_db_multi_az
  vpc_security_group_ids = [aws_security_group.rds.id]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  # InnoDB buffer pool ~ 70% of instance RAM is a reasonable starting point; MISP is
  # read-heavy on correlation. Tune via `parameters` (list of DB parameter maps) for
  # real load; left empty here to take the RDS family defaults.
  parameters = []

  backup_retention_period = 7
  deletion_protection     = var.production  # protected in prod; disposable in the lab
  skip_final_snapshot     = !var.production # take a final snapshot in prod, skip in the lab
}
