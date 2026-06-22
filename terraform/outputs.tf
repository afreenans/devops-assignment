

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

# ========================================
# ALB Outputs
# ========================================

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "Security group ID of ALB"
  value       = aws_security_group.alb.id
}

# ========================================
# EC2 Outputs
# ========================================

output "app_server_id" {
  description = "EC2 instance ID of application server"
  value       = aws_instance.app_server.id
}

output "app_server_private_ip" {
  description = "Private IP of application server"
  value       = aws_instance.app_server.private_ip
}

output "app_server_security_group_id" {
  description = "Security group ID of app server"
  value       = aws_security_group.ec2.id
}

# ========================================
# Bastion Outputs
# ========================================

output "bastion_public_ip" {
  description = "Public IP of Bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "bastion_host_ssh_command" {
  description = "SSH command to connect to Bastion"
  value = var.enable_bastion ? format(
    "ssh -i /path/to/key.pem ec2-user@%s",
    aws_instance.bastion[0].public_ip
  ) : null
}

output "bastion_security_group_id" {
  description = "Security group ID of Bastion"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}

# ========================================
# RDS Outputs
# ========================================

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS instance address (hostname only)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.main.username
}

output "rds_security_group_id" {
  description = "Security group ID of RDS"
  value       = aws_security_group.rds.id
}

output "rds_connection_string" {
  description = "PostgreSQL connection string"
  value = format(
    "postgresql://%s:****@%s:%d/%s",
    aws_db_instance.main.username,
    aws_db_instance.main.address,
    aws_db_instance.main.port,
    aws_db_instance.main.db_name
  )
  sensitive = true
}

# ========================================
# Summary Outputs
# ========================================

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment       = var.environment
    region           = var.aws_region
    vpc_cidr         = aws_vpc.main.cidr_block
    instance_type    = var.instance_type
    database         = "PostgreSQL ${var.db_engine_version}"
    bastion_enabled  = var.enable_bastion
    app_url          = "http://${aws_lb.main.dns_name}"
  }
}
