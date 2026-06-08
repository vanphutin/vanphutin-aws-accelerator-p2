output "instance_id" {
  description = "Web EC2 instance ID."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Web EC2 public IP."
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "Web EC2 public DNS."
  value       = aws_instance.web.public_dns
}
