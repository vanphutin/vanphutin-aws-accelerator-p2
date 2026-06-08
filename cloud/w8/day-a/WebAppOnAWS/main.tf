locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  allowed_ssh = var.allowed_ssh_cidr_blocks
  web_ingress = var.web_ingress_cidr_blocks
  mysql_port  = var.mysql_port
}

module "s3_static_assets" {
  source = "./modules/s3"

  bucket_name   = var.static_assets_bucket_name
  name_prefix   = local.name_prefix
  force_destroy = var.static_assets_force_destroy
}

module "rds" {
  source = "./modules/rds"

  name_prefix             = local.name_prefix
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  db_instance_class       = var.db_instance_class
  db_allocated_storage    = var.db_allocated_storage
  db_engine_version       = var.db_engine_version
  db_port                 = var.mysql_port
  private_subnet_ids      = module.vpc.private_subnet_ids
  db_security_group_ids   = [module.security_groups.rds_security_group_id]
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
}

module "ec2_web" {
  source = "./modules/ec2"

  name_prefix        = local.name_prefix
  instance_type      = var.web_instance_type
  key_name           = var.key_name
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]
  db_endpoint        = module.rds.db_endpoint
  db_name            = var.db_name
  db_username        = var.db_username
  static_bucket_name = module.s3_static_assets.bucket_name
}
