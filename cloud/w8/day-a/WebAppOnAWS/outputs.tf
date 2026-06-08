output "vpc_id" {
  description = "Created VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "web_instance_id" {
  description = "Web EC2 instance ID."
  value       = module.ec2_web.instance_id
}

output "web_public_ip" {
  description = "Public IP address for the web server."
  value       = module.ec2_web.public_ip
}

output "web_url" {
  description = "HTTP URL for the web server."
  value       = "http://${module.ec2_web.public_dns}"
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint."
  value       = module.rds.db_endpoint
}

output "static_assets_bucket_name" {
  description = "S3 bucket for static assets."
  value       = module.s3_static_assets.bucket_name
}
