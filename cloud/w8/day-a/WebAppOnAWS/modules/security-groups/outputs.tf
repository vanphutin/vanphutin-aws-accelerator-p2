output "web_security_group_id" {
  description = "Web security group ID."
  value       = aws_security_group.web.id
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.rds.id
}
